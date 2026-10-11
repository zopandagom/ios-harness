import ProjectDescription
import ProjectDescriptionHelpers

let project = Project.app(
  infoPlist: [
    "CFBundleDisplayName": "__DISPLAY_NAME__",
  ],
  dependencies: [
    .feature(.home),
    .shared(.core),
  ]
)
