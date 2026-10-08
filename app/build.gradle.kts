plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    id("org.jetbrains.kotlin.plugin.compose")
}
android {
    namespace="com.parin.office"
    compileSdk=37
    defaultConfig {
        applicationId="com.parin.office"
        minSdk=28
        targetSdk=37
        versionCode=System.getenv("VERSION_CODE")?.toIntOrNull() ?: 1
        versionName=System.getenv("VERSION_NAME") ?: "0.1.0"
    }
    buildTypes {
        release {
            isMinifyEnabled=true
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"),"proguard-rules.pro")
        }
        debug { applicationIdSuffix=".debug" }
    }
    splits {
        abi {
            isEnable=true
            reset()
            include("armeabi-v7a","arm64-v8a","x86_64")
            isUniversalApk=true
        }
    }
    packaging.resources.excludes += "/META-INF/{AL2.0,LGPL2.1,NOTICE,NOTICE.txt,LICENSE,LICENSE.txt}"
    buildFeatures { compose=true }
    compileOptions { sourceCompatibility=JavaVersion.VERSION_17; targetCompatibility=JavaVersion.VERSION_17 }
    kotlinOptions { jvmTarget="17" }
}
dependencies {
    val composeBom=platform("androidx.compose:compose-bom:2026.09.00")
    implementation(composeBom)
    implementation("androidx.activity:activity-compose:1.13.0")
    implementation("androidx.core:core-ktx:1.19.1")
    implementation("androidx.appcompat:appcompat:1.8.0")
    implementation("androidx.compose.foundation:foundation")
    implementation("androidx.compose.material3:material3")
    implementation("androidx.compose.ui:ui")
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android:1.11.0")
}
