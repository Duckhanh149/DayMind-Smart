plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val productionSigning = System.getenv("DAYMIND_REQUIRE_RELEASE_SIGNING") == "true"
val signingVariables = listOf("DAYMIND_ANDROID_KEYSTORE_PATH", "DAYMIND_ANDROID_STORE_PASSWORD", "DAYMIND_ANDROID_KEY_ALIAS", "DAYMIND_ANDROID_KEY_PASSWORD")
if (productionSigning && signingVariables.any { System.getenv(it).isNullOrBlank() }) {
    throw GradleException("Production signing configuration is incomplete. Configure GitHub Actions secrets; do not put keys/passwords in source.")
}

android {
    namespace = "dev.daymind.daymind_smart"
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "dev.daymind.daymind_smart"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (productionSigning) {
            create("production") {
                storeFile = file(System.getenv("DAYMIND_ANDROID_KEYSTORE_PATH"))
                storePassword = System.getenv("DAYMIND_ANDROID_STORE_PASSWORD")
                keyAlias = System.getenv("DAYMIND_ANDROID_KEY_ALIAS")
                keyPassword = System.getenv("DAYMIND_ANDROID_KEY_PASSWORD")
            }
        }
    }
    buildTypes {
        release {
            // Preview remains explicit. Production mode never falls back to a debug key.
            signingConfig = signingConfigs.getByName(if (productionSigning) "production" else "debug")
        }
    }
    testOptions {
        unitTests.isIncludeAndroidResources = true
        unitTests.all {
            it.testLogging.exceptionFormat = org.gradle.api.tasks.testing.logging.TestExceptionFormat.FULL
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}

androidComponents {
    beforeVariants(selector().all()) { variant ->
        (variant as com.android.build.api.variant.HasUnitTestBuilder).enableUnitTest = true
    }
}

// AGP host-test packaging consumes the assets directory that Flutter augments.
// Declare the producer explicitly so Gradle validates the task graph.
tasks.configureEach {
    val variant = Regex("^package(.+)UnitTestForUnitTest$").matchEntire(name)
        ?.groupValues?.get(1)
    if (variant != null) dependsOn("copyFlutterAssets$variant")
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
    implementation("androidx.core:core-ktx:1.17.0")
    testImplementation("junit:junit:4.13.2")
    testImplementation("org.robolectric:robolectric:4.14.1")
}
