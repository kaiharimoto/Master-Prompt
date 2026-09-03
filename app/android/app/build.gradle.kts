import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.masterprompt.master_prompt"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.masterprompt.master_prompt"
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

    // The development signing key, committed to the repository on purpose.
    //
    // CI generates a fresh debug key on every run, which makes each build a
    // different application as far as Android is concerned: installing a new one
    // would require uninstalling the old one first, deleting any missions saved
    // on the device. Signing every build with one fixed key is what lets a new
    // dev build install straight over the last.
    //
    // This key is PUBLIC. It must never sign a Play Store release — see the note
    // in android/.gitignore.
    signingConfigs {
        create("dev") {
            val props = Properties()
            val file = rootProject.file("dev-key.properties")
            if (file.exists()) {
                props.load(FileInputStream(file))
                storeFile = rootProject.file(props.getProperty("storeFile"))
                storePassword = props.getProperty("storePassword")
                keyAlias = props.getProperty("keyAlias")
                keyPassword = props.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            // Fall back to the debug key only if the dev keystore is missing, so a
            // checkout without it still builds rather than failing obscurely.
            signingConfig = if (rootProject.file("dev-key.properties").exists()) {
                signingConfigs.getByName("dev")
            } else {
                signingConfigs.getByName("debug")
            }
        }
    }
}

dependencies {
    // FileProvider, used to hand the downloaded APK to the package installer.
    // Declared rather than relied on transitively through the Flutter
    // embedding, so an embedding change cannot silently break the updater.
    implementation("androidx.core:core-ktx:1.13.1")
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
