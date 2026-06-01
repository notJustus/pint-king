package com.pintking.api.migration

import io.kotest.core.spec.style.DescribeSpec
import io.kotest.matchers.collections.shouldContainAll
import io.kotest.matchers.shouldBe
import org.flywaydb.core.Flyway
import org.testcontainers.containers.PostgreSQLContainer
import org.testcontainers.utility.DockerImageName
import java.sql.Connection
import java.sql.DriverManager

class FlywayMigrationTest : DescribeSpec({

    val postgis = DockerImageName.parse("postgis/postgis:16-3.4")
        .asCompatibleSubstituteFor("postgres")

    val postgres = PostgreSQLContainer(postgis)
        .withDatabaseName("pintking_test")
        .withUsername("test")
        .withPassword("test")

    beforeSpec {
        postgres.start()

        Flyway.configure()
            .dataSource(postgres.jdbcUrl, postgres.username, postgres.password)
            .locations("classpath:db/migration")
            .load()
            .migrate()
    }

    afterSpec {
        postgres.stop()
    }

    fun connection(): Connection =
        DriverManager.getConnection(postgres.jdbcUrl, postgres.username, postgres.password)

    fun tableExists(conn: Connection, table: String): Boolean {
        val rs = conn.metaData.getTables(null, "public", table, arrayOf("TABLE"))
        return rs.next()
    }

    fun columnNames(conn: Connection, table: String): List<String> {
        val rs = conn.metaData.getColumns(null, "public", table, null)
        val cols = mutableListOf<String>()
        while (rs.next()) {
            cols.add(rs.getString("COLUMN_NAME"))
        }
        return cols
    }

    fun indexNames(conn: Connection, table: String): List<String> {
        val rs = conn.metaData.getIndexInfo(null, "public", table, false, false)
        val indexes = mutableListOf<String>()
        while (rs.next()) {
            rs.getString("INDEX_NAME")?.let { indexes.add(it) }
        }
        return indexes.distinct()
    }

    describe("Flyway migrations run successfully") {

        it("creates the users table with correct columns") {
            connection().use { conn ->
                tableExists(conn, "users") shouldBe true
                columnNames(conn, "users") shouldContainAll listOf(
                    "id", "apple_id", "display_name", "avatar_url",
                    "active_group_id", "created_at", "updated_at"
                )
            }
        }

        it("creates the groups table with correct columns") {
            connection().use { conn ->
                tableExists(conn, "groups") shouldBe true
                columnNames(conn, "groups") shouldContainAll listOf(
                    "id", "name", "invite_code", "created_by",
                    "created_at", "updated_at"
                )
            }
        }

        it("creates the group_members table with correct columns") {
            connection().use { conn ->
                tableExists(conn, "group_members") shouldBe true
                columnNames(conn, "group_members") shouldContainAll listOf(
                    "id", "user_id", "group_id", "role", "joined_at"
                )
            }
        }

        it("creates the group_blocks table with correct columns") {
            connection().use { conn ->
                tableExists(conn, "group_blocks") shouldBe true
                columnNames(conn, "group_blocks") shouldContainAll listOf(
                    "id", "group_id", "user_id", "blocked_at"
                )
            }
        }

        it("creates the pint_logs table with correct columns") {
            connection().use { conn ->
                tableExists(conn, "pint_logs") shouldBe true
                columnNames(conn, "pint_logs") shouldContainAll listOf(
                    "id", "user_id", "group_id", "photo_url",
                    "note", "drink_type", "location", "logged_at"
                )
            }
        }

        it("creates the refresh_tokens table with correct columns") {
            connection().use { conn ->
                tableExists(conn, "refresh_tokens") shouldBe true
                columnNames(conn, "refresh_tokens") shouldContainAll listOf(
                    "id", "user_id", "token_hash", "used",
                    "expires_at", "created_at"
                )
            }
        }

        it("creates the leaderboard_snapshots table with correct columns") {
            connection().use { conn ->
                tableExists(conn, "leaderboard_snapshots") shouldBe true
                columnNames(conn, "leaderboard_snapshots") shouldContainAll listOf(
                    "id", "group_id", "user_id", "period_type",
                    "period_key", "rank", "pint_count", "snapshot_at"
                )
            }
        }

        it("creates indexes on pint_logs") {
            connection().use { conn ->
                val indexes = indexNames(conn, "pint_logs")
                indexes shouldContainAll listOf(
                    "idx_pint_logs_group_logged",
                    "idx_pint_logs_user_logged",
                    "idx_pint_logs_location"
                )
            }
        }

        it("creates index on refresh_tokens") {
            connection().use { conn ->
                val indexes = indexNames(conn, "refresh_tokens")
                indexes shouldContainAll listOf("idx_refresh_tokens_user")
            }
        }

        it("creates index on leaderboard_snapshots") {
            connection().use { conn ->
                val indexes = indexNames(conn, "leaderboard_snapshots")
                indexes shouldContainAll listOf("idx_snapshots_lookup")
            }
        }

        it("creates index on group_blocks") {
            connection().use { conn ->
                val indexes = indexNames(conn, "group_blocks")
                indexes shouldContainAll listOf("idx_group_blocks_lookup")
            }
        }

        it("enforces unique constraint on users.apple_id") {
            connection().use { conn ->
                conn.createStatement().execute(
                    """INSERT INTO users (id, apple_id, display_name)
                       VALUES (gen_random_uuid(), 'apple_123', 'Test User')"""
                )
                val ex = runCatching {
                    conn.createStatement().execute(
                        """INSERT INTO users (id, apple_id, display_name)
                           VALUES (gen_random_uuid(), 'apple_123', 'Duplicate')"""
                    )
                }
                ex.isFailure shouldBe true
            }
        }

        it("enforces unique constraint on group_members (user_id, group_id)") {
            connection().use { conn ->
                conn.autoCommit = false
                conn.createStatement().execute(
                    "INSERT INTO users (id, apple_id, display_name) VALUES (gen_random_uuid(), 'gm_uniq', 'Uniq Test')"
                )
                val rs = conn.createStatement().executeQuery(
                    "SELECT id FROM users WHERE apple_id = 'gm_uniq'"
                )
                rs.next()
                val uid = rs.getString("id")

                conn.createStatement().execute(
                    "INSERT INTO groups (id, name, invite_code, created_by) VALUES (gen_random_uuid(), 'Uniq Group', 'UNIQ1234', '$uid'::uuid)"
                )
                val grs = conn.createStatement().executeQuery(
                    "SELECT id FROM groups WHERE invite_code = 'UNIQ1234'"
                )
                grs.next()
                val gid = grs.getString("id")

                conn.createStatement().execute(
                    "INSERT INTO group_members (id, user_id, group_id, role) VALUES (gen_random_uuid(), '$uid'::uuid, '$gid'::uuid, 'admin')"
                )
                val ex = runCatching {
                    conn.createStatement().execute(
                        "INSERT INTO group_members (id, user_id, group_id, role) VALUES (gen_random_uuid(), '$uid'::uuid, '$gid'::uuid, 'member')"
                    )
                }
                ex.isFailure shouldBe true
                conn.rollback()
            }
        }

        it("enforces check constraint on group_members.role") {
            connection().use { conn ->
                conn.autoCommit = false
                conn.createStatement().execute(
                    "INSERT INTO users (id, apple_id, display_name) VALUES (gen_random_uuid(), 'role_test', 'Role Test')"
                )
                val rs = conn.createStatement().executeQuery("SELECT id FROM users WHERE apple_id = 'role_test'")
                rs.next()
                val uid = rs.getString("id")

                conn.createStatement().execute(
                    "INSERT INTO groups (id, name, invite_code, created_by) VALUES (gen_random_uuid(), 'Role Group', 'ROLE1234', '$uid'::uuid)"
                )
                val grs = conn.createStatement().executeQuery("SELECT id FROM groups WHERE invite_code = 'ROLE1234'")
                grs.next()
                val gid = grs.getString("id")

                val ex = runCatching {
                    conn.createStatement().execute(
                        "INSERT INTO group_members (id, user_id, group_id, role) VALUES (gen_random_uuid(), '$uid'::uuid, '$gid'::uuid, 'invalid_role')"
                    )
                }
                ex.isFailure shouldBe true
                conn.rollback()
            }
        }

        it("enforces check constraint on pint_logs.drink_type") {
            connection().use { conn ->
                conn.autoCommit = false
                conn.createStatement().execute(
                    "INSERT INTO users (id, apple_id, display_name) VALUES (gen_random_uuid(), 'drink_test', 'Drink Test')"
                )
                val rs = conn.createStatement().executeQuery("SELECT id FROM users WHERE apple_id = 'drink_test'")
                rs.next()
                val uid = rs.getString("id")

                conn.createStatement().execute(
                    "INSERT INTO groups (id, name, invite_code, created_by) VALUES (gen_random_uuid(), 'Drink Group', 'DRNK1234', '$uid'::uuid)"
                )
                val grs = conn.createStatement().executeQuery("SELECT id FROM groups WHERE invite_code = 'DRNK1234'")
                grs.next()
                val gid = grs.getString("id")

                val ex = runCatching {
                    conn.createStatement().execute(
                        "INSERT INTO pint_logs (id, user_id, group_id, photo_url, drink_type) VALUES (gen_random_uuid(), '$uid'::uuid, '$gid'::uuid, 'http://photo.jpg', 'wine')"
                    )
                }
                ex.isFailure shouldBe true
                conn.rollback()
            }
        }
    }
})
