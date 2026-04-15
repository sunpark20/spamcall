#!/usr/bin/env python3
"""LimitTest project.yml 생성 스크립트."""

EXT_COUNT = 67

header = """name: LimitTest
options:
  bundleIdPrefix: com.limittest
  deploymentTarget:
    iOS: "16.0"

settings:
  base:
    DEVELOPMENT_TEAM: GA2LMK5XL2
    CODE_SIGN_STYLE: Automatic
    SWIFT_VERSION: "5.0"

targets:
  LimitTestApp:
    type: application
    platform: iOS
    sources:
      - LimitTestApp
    info:
      path: LimitTestApp/Info.plist
      properties:
        CFBundleDisplayName: LimitTest
        UILaunchScreen: {}
        UISupportedInterfaceOrientations:
          - UIInterfaceOrientationPortrait
          - UIInterfaceOrientationLandscapeLeft
          - UIInterfaceOrientationLandscapeRight
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: com.limittest50.app
        CODE_SIGN_ENTITLEMENTS: LimitTestApp/LimitTestApp.entitlements
        MARKETING_VERSION: "1.0"
        CURRENT_PROJECT_VERSION: "1"
    scheme:
      testTargets: []
      gatherCoverageData: false
    dependencies:
"""

ext_template = """
  LimitTestExt{padded}:
    type: app-extension
    platform: iOS
    sources:
      - path: LimitTestBase
    info:
      path: LimitTestExt{padded}/Info.plist
      properties:
        NSExtension:
          NSExtensionPointIdentifier: com.apple.callkit.call-directory
          NSExtensionPrincipalClass: $(PRODUCT_MODULE_NAME).CallDirectoryHandler
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: com.limittest50.app.LimitTestExt{padded}
        CODE_SIGN_ENTITLEMENTS: LimitTestApp/LimitTestExt.entitlements
"""

dep_template = "      - target: LimitTestExt{padded}\n"

lines = [header]

for i in range(EXT_COUNT):
    padded = f"{i:03d}"
    lines.append(dep_template.format(padded=padded))

for i in range(EXT_COUNT):
    padded = f"{i:03d}"
    lines.append(ext_template.format(padded=padded))

with open("project.yml", "w") as f:
    f.write("".join(lines))

print(f"Generated project.yml with {EXT_COUNT} extension targets")
