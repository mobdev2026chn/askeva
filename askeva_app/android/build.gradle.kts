allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)

    // Some plugins (e.g. flutter_plugin_android_lifecycle pulled in by
    // file_picker) require consumers to compile against Android API 36+.
    // Force every Android module to compileSdk 36 so plugin modules match :app.
    // Registered here (before the evaluationDependsOn below triggers
    // evaluation) so afterEvaluate is always in time.
    afterEvaluate {
        extensions.findByName("android")?.let { ext ->
            val androidExt = ext as com.android.build.gradle.BaseExtension
            val current = androidExt.compileSdkVersion?.removePrefix("android-")?.toIntOrNull() ?: 0
            if (current < 36) {
                androidExt.compileSdkVersion(36)
            }
        }
    }
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
