package com.pintking.api

import org.springframework.boot.autoconfigure.SpringBootApplication
import org.springframework.boot.runApplication

@SpringBootApplication
class PintKingApplication

fun main(args: Array<String>) {
    runApplication<PintKingApplication>(*args)
}
