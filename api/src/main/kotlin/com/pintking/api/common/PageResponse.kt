package com.pintking.api.common

data class PageResponse<T>(
    val data: List<T>,
    val page: Int,
    val size: Int,
    val total: Long
)
