package com.pintking.api.user

import com.pintking.api.auth.RefreshTokenRepository
import com.pintking.api.common.NotFoundException
import com.pintking.api.group.GroupBlockRepository
import com.pintking.api.group.GroupMemberEntity
import com.pintking.api.group.GroupMemberRepository
import com.pintking.api.group.GroupRepository
import com.pintking.api.leaderboard.LeaderboardSnapshotRepository
import com.pintking.api.pint.PintLogRepository
import com.pintking.api.storage.S3CleanupDispatcher
import org.springframework.stereotype.Service
import org.springframework.transaction.annotation.Transactional
import org.springframework.transaction.support.TransactionSynchronization
import org.springframework.transaction.support.TransactionSynchronizationManager
import java.util.UUID

@Service
class AccountService(
    private val userRepository: UserRepository,
    private val groupRepository: GroupRepository,
    private val groupMemberRepository: GroupMemberRepository,
    private val groupBlockRepository: GroupBlockRepository,
    private val pintLogRepository: PintLogRepository,
    private val refreshTokenRepository: RefreshTokenRepository,
    private val leaderboardSnapshotRepository: LeaderboardSnapshotRepository,
    private val s3CleanupDispatcher: S3CleanupDispatcher
) {

    /**
     * Deletes the user and everything that references them in a single transaction,
     * then dispatches async S3 deletion of their photos once the commit succeeds.
     *
     * Group fate per membership:
     *  - sole member         → the group (and its dependent rows) is deleted
     *  - sole admin + others → the longest-standing other member is promoted to admin
     *  - otherwise           → the membership is simply removed
     */
    @Transactional
    fun deleteAccount(userId: UUID) {
        val user = userRepository.findById(userId).orElseThrow {
            NotFoundException("User not found")
        }

        // Collect S3 keys up front — the DB rows holding them are about to be deleted.
        val s3Keys = mutableListOf<String>()
        pintLogRepository.findByUserId(userId).forEach { s3Keys.add(it.photoUrl) }
        user.avatarUrl?.let { s3Keys.add(it) }

        // Break the users.active_group_id → groups reference before any group is removed.
        user.activeGroupId = null
        userRepository.save(user)

        val deletedGroupIds = mutableSetOf<UUID>()

        // Resolve the fate of every group the user is a member of.
        groupMemberRepository.findByUserId(userId).forEach { membership ->
            val groupId = membership.groupId
            val others = groupMemberRepository.findByGroupId(groupId)
                .filter { it.userId != userId }

            if (others.isEmpty()) {
                deleteGroup(groupId)
                deletedGroupIds.add(groupId)
            } else if (membership.role == GroupMemberEntity.ROLE_ADMIN &&
                others.none { it.role == GroupMemberEntity.ROLE_ADMIN }
            ) {
                // Sole admin leaving a group with other members → promote the eldest.
                val heir = others.minByOrNull { it.joinedAt }!!
                heir.role = GroupMemberEntity.ROLE_ADMIN
                groupMemberRepository.save(heir)
            }
        }

        // groups.created_by is NOT NULL → surviving groups the user created must
        // hand ownership to a remaining member before the user row can be deleted.
        groupRepository.findByCreatedBy(userId).forEach { group ->
            if (group.id in deletedGroupIds) return@forEach
            val heir = groupMemberRepository.findByGroupId(group.id!!)
                .filter { it.userId != userId }
                .minByOrNull { it.joinedAt }!!
            group.createdBy = heir.userId
            groupRepository.save(group)
        }

        // Remove everything else that references the user, then the user itself.
        pintLogRepository.deleteByUserId(userId)
        refreshTokenRepository.deleteByUserId(userId)
        leaderboardSnapshotRepository.deleteByUserId(userId)
        groupBlockRepository.deleteByUserId(userId)
        groupMemberRepository.deleteByUserId(userId)
        userRepository.deleteById(userId)

        dispatchS3CleanupAfterCommit(s3Keys)
    }

    private fun deleteGroup(groupId: UUID) {
        // A sole-member group can still hold rows from former members (pints they
        // left behind, blocks, snapshots), all of which reference this group.
        pintLogRepository.deleteByGroupId(groupId)
        groupBlockRepository.deleteByGroupId(groupId)
        leaderboardSnapshotRepository.deleteByGroupId(groupId)
        groupMemberRepository.deleteByGroupId(groupId)
        groupRepository.deleteById(groupId)
    }

    private fun dispatchS3CleanupAfterCommit(keys: List<String>) {
        if (keys.isEmpty()) return
        // Only fire once the DB delete is durable; a rollback must not orphan-delete photos.
        TransactionSynchronizationManager.registerSynchronization(
            object : TransactionSynchronization {
                override fun afterCommit() {
                    s3CleanupDispatcher.deleteObjects(keys)
                }
            }
        )
    }
}
