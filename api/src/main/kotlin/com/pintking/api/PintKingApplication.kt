package com.pintking.api

import org.springframework.boot.autoconfigure.SpringBootApplication
import org.springframework.boot.runApplication
import org.springframework.scheduling.annotation.EnableAsync

@SpringBootApplication
@EnableAsync
class PintKingApplication

fun main(args: Array<String>) {
    runApplication<PintKingApplication>(*args)
}
