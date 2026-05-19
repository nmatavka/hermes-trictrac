plugins {
    kotlin("jvm") version "2.3.0"
    id("io.ktor.plugin") version "3.4.0"
    kotlin("plugin.serialization") version "2.3.0"
    id("app.cash.sqldelight") version "2.2.1"
    application
}

group = "org.example"
version = "1.0-SNAPSHOT"

repositories {
    mavenCentral()
}

application {
    mainClass.set("ApplicationKt")
}

dependencies {
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-core:1.8.0")
    implementation("com.lordcodes.turtle:turtle:0.10.0")
    implementation("org.jetbrains.kotlinx:kotlinx-serialization-json:1.8.0")

    implementation("ch.qos.logback:logback-classic:1.5.25")

    implementation("io.github.cdimascio:dotenv-kotlin:6.4.1")
    implementation("com.expediagroup", "graphql-kotlin-ktor-server", "8.3.0")

    implementation("org.xerial:sqlite-jdbc:3.51.1.0")

    implementation("io.ktor:ktor-server-websockets:3.4.0")
    implementation("io.ktor:ktor-server-core:3.4.0")
    implementation("io.ktor:ktor-server-netty:3.4.0")
    implementation("io.ktor:ktor-server-cors:3.4.0")
    testImplementation("io.kotest:kotest-runner-junit5:5.7.2")

    implementation("app.cash.sqldelight:runtime:2.2.1")
    implementation("app.cash.sqldelight:sqlite-driver:2.2.1")
    implementation("app.cash.sqldelight:coroutines-extensions:2.2.1")
    implementation("app.cash.sqldelight:jdbc-driver:2.2.1")

    implementation("org.apache.commons:commons-exec:1.4.0")
    implementation("com.github.pgreze:kotlin-process:1.5.1")
}

tasks.test {
    testClassesDirs = sourceSets["main"].output.classesDirs + sourceSets["test"].output.classesDirs

    useJUnitPlatform()
}
kotlin {
    jvmToolchain(25)
}

sqldelight {
    databases {
        create("BackgammonDatabase") {
            deriveSchemaFromMigrations = true
            packageName.set("com.kyleth95.backgammon")
        }
    }
}

distributions {
    main {
        contents {
            from("Dockerfile")
        }
    }
}

ktor {
    docker {

        jreVersion.set(JavaVersion.VERSION_25)
    }
}