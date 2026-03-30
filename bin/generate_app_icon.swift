import AppKit
import Foundation

let fileManager = FileManager.default
let projectRoot = URL(fileURLWithPath: fileManager.currentDirectoryPath)
let sourceURL = projectRoot.appendingPathComponent("assets/branding/app_icon_source.png")

let canvasSize = CGSize(width: 1024, height: 1024)
let image = NSImage(size: canvasSize)

image.lockFocus()
guard let context = NSGraphicsContext.current?.cgContext else {
  fputs("Failed to create graphics context\n", stderr)
  exit(1)
}

let fullRect = CGRect(origin: .zero, size: canvasSize)

func rgb(_ red: CGFloat, _ green: CGFloat, _ blue: CGFloat, _ alpha: CGFloat = 1) -> NSColor {
  NSColor(calibratedRed: red / 255, green: green / 255, blue: blue / 255, alpha: alpha)
}

context.interpolationQuality = .high
context.setShouldAntialias(true)

let skyColors = [
  rgb(117, 193, 255).cgColor,
  rgb(66, 151, 234).cgColor,
  rgb(38, 110, 199).cgColor,
]
let skyLocations: [CGFloat] = [0, 0.55, 1]
let skyGradient = CGGradient(
  colorsSpace: CGColorSpaceCreateDeviceRGB(),
  colors: skyColors as CFArray,
  locations: skyLocations
)!
context.drawLinearGradient(
  skyGradient,
  start: CGPoint(x: 512, y: 1024),
  end: CGPoint(x: 512, y: 0),
  options: []
)

let glowColors = [
  rgb(255, 255, 255, 0.42).cgColor,
  rgb(255, 255, 255, 0.0).cgColor,
]
let glowGradient = CGGradient(
  colorsSpace: CGColorSpaceCreateDeviceRGB(),
  colors: glowColors as CFArray,
  locations: [0, 1]
)!
context.drawRadialGradient(
  glowGradient,
  startCenter: CGPoint(x: 350, y: 780),
  startRadius: 0,
  endCenter: CGPoint(x: 350, y: 780),
  endRadius: 420,
  options: []
)

func drawCloud(center: CGPoint, scale: CGFloat, alpha: CGFloat) {
  context.saveGState()
  let cloudColor = rgb(255, 255, 255, alpha).cgColor
  context.setFillColor(cloudColor)

  let ellipses = [
    CGRect(x: center.x - 130 * scale, y: center.y - 28 * scale, width: 160 * scale, height: 78 * scale),
    CGRect(x: center.x - 30 * scale, y: center.y - 46 * scale, width: 170 * scale, height: 92 * scale),
    CGRect(x: center.x + 72 * scale, y: center.y - 24 * scale, width: 120 * scale, height: 68 * scale),
  ]
  for ellipse in ellipses {
    context.fillEllipse(in: ellipse)
  }
  context.restoreGState()
}

drawCloud(center: CGPoint(x: 290, y: 700), scale: 1.0, alpha: 0.18)
drawCloud(center: CGPoint(x: 760, y: 770), scale: 0.82, alpha: 0.12)
drawCloud(center: CGPoint(x: 810, y: 565), scale: 0.64, alpha: 0.09)

context.saveGState()
context.translateBy(x: 530, y: 486)
context.rotate(by: .pi / 10)

let shadowPath = CGMutablePath()
shadowPath.move(to: CGPoint(x: -138, y: -96))
shadowPath.addCurve(to: CGPoint(x: 104, y: -116), control1: CGPoint(x: -54, y: -160), control2: CGPoint(x: 44, y: -158))
shadowPath.addCurve(to: CGPoint(x: 168, y: 44), control1: CGPoint(x: 162, y: -78), control2: CGPoint(x: 204, y: -4))
shadowPath.addCurve(to: CGPoint(x: 4, y: 154), control1: CGPoint(x: 146, y: 118), control2: CGPoint(x: 72, y: 170))
shadowPath.addCurve(to: CGPoint(x: -154, y: 38), control1: CGPoint(x: -82, y: 144), control2: CGPoint(x: -164, y: 106))
shadowPath.closeSubpath()

context.setShadow(offset: CGSize(width: 0, height: -18), blur: 44, color: rgb(13, 56, 109, 0.32).cgColor)
context.addPath(shadowPath)
context.setFillColor(rgb(0, 0, 0, 0.12).cgColor)
context.fillPath()
context.restoreGState()

context.saveGState()
context.translateBy(x: 530, y: 486)
context.rotate(by: .pi / 10)

let grainPath = CGMutablePath()
grainPath.move(to: CGPoint(x: -144, y: -82))
grainPath.addCurve(to: CGPoint(x: 110, y: -112), control1: CGPoint(x: -66, y: -158), control2: CGPoint(x: 30, y: -156))
grainPath.addCurve(to: CGPoint(x: 180, y: 46), control1: CGPoint(x: 174, y: -70), control2: CGPoint(x: 216, y: 8))
grainPath.addCurve(to: CGPoint(x: -2, y: 168), control1: CGPoint(x: 160, y: 126), control2: CGPoint(x: 74, y: 184))
grainPath.addCurve(to: CGPoint(x: -170, y: 42), control1: CGPoint(x: -96, y: 156), control2: CGPoint(x: -184, y: 108))
grainPath.closeSubpath()

context.addPath(grainPath)
context.clip()

let grainColors = [
  rgb(255, 231, 181).cgColor,
  rgb(231, 194, 123).cgColor,
  rgb(180, 133, 73).cgColor,
]
let grainGradient = CGGradient(
  colorsSpace: CGColorSpaceCreateDeviceRGB(),
  colors: grainColors as CFArray,
  locations: [0, 0.55, 1]
)!
context.drawLinearGradient(
  grainGradient,
  start: CGPoint(x: -100, y: 170),
  end: CGPoint(x: 150, y: -130),
  options: []
)

context.setBlendMode(.screen)
context.setFillColor(rgb(255, 255, 255, 0.30).cgColor)
context.fillEllipse(in: CGRect(x: -92, y: 16, width: 180, height: 86))
context.fillEllipse(in: CGRect(x: -18, y: -78, width: 136, height: 54))

context.setBlendMode(.multiply)
context.setFillColor(rgb(156, 111, 57, 0.22).cgColor)
context.fillEllipse(in: CGRect(x: 8, y: -18, width: 160, height: 120))

context.resetClip()
context.addPath(grainPath)
context.setLineWidth(7)
context.setStrokeColor(rgb(255, 244, 214, 0.35).cgColor)
context.strokePath()
context.restoreGState()

func drawParticle(center: CGPoint, radius: CGFloat, alpha: CGFloat) {
  context.saveGState()
  context.setShadow(offset: CGSize(width: 0, height: -4), blur: 8, color: rgb(40, 83, 143, 0.16).cgColor)
  context.setFillColor(rgb(245, 217, 154, alpha).cgColor)
  context.fillEllipse(in: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2))
  context.restoreGState()
}

drawParticle(center: CGPoint(x: 336, y: 604), radius: 12, alpha: 0.92)
drawParticle(center: CGPoint(x: 294, y: 548), radius: 8, alpha: 0.78)
drawParticle(center: CGPoint(x: 724, y: 376), radius: 10, alpha: 0.84)
drawParticle(center: CGPoint(x: 770, y: 338), radius: 6, alpha: 0.68)

let shimmerPath = CGMutablePath()
shimmerPath.move(to: CGPoint(x: 194, y: 256))
shimmerPath.addCurve(to: CGPoint(x: 432, y: 192), control1: CGPoint(x: 264, y: 298), control2: CGPoint(x: 352, y: 240))
shimmerPath.addCurve(to: CGPoint(x: 718, y: 232), control1: CGPoint(x: 512, y: 144), control2: CGPoint(x: 632, y: 188))
context.saveGState()
context.addPath(shimmerPath)
context.setLineWidth(16)
context.setLineCap(.round)
context.setStrokeColor(rgb(255, 255, 255, 0.12).cgColor)
context.strokePath()
context.restoreGState()

image.unlockFocus()

guard
  let tiff = image.tiffRepresentation,
  let bitmap = NSBitmapImageRep(data: tiff),
  let pngData = bitmap.representation(using: .png, properties: [:])
else {
  fputs("Failed to encode PNG\n", stderr)
  exit(1)
}

try fileManager.createDirectory(at: sourceURL.deletingLastPathComponent(), withIntermediateDirectories: true)
try pngData.write(to: sourceURL)

let outputs: [(String, Int)] = [
  ("web/favicon.png", 64),
  ("web/icons/Icon-192.png", 192),
  ("web/icons/Icon-512.png", 512),
  ("web/icons/Icon-maskable-192.png", 192),
  ("web/icons/Icon-maskable-512.png", 512),
  ("android/app/src/main/res/mipmap-mdpi/ic_launcher.png", 48),
  ("android/app/src/main/res/mipmap-hdpi/ic_launcher.png", 72),
  ("android/app/src/main/res/mipmap-xhdpi/ic_launcher.png", 96),
  ("android/app/src/main/res/mipmap-xxhdpi/ic_launcher.png", 144),
  ("android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png", 192),
  ("ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-20x20@1x.png", 20),
  ("ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-20x20@2x.png", 40),
  ("ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-20x20@3x.png", 60),
  ("ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-29x29@1x.png", 29),
  ("ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-29x29@2x.png", 58),
  ("ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-29x29@3x.png", 87),
  ("ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-40x40@1x.png", 40),
  ("ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-40x40@2x.png", 80),
  ("ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-40x40@3x.png", 120),
  ("ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-60x60@2x.png", 120),
  ("ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-60x60@3x.png", 180),
  ("ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-76x76@1x.png", 76),
  ("ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-76x76@2x.png", 152),
  ("ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-83.5x83.5@2x.png", 167),
  ("ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-1024x1024@1x.png", 1024),
  ("macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_16.png", 16),
  ("macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_32.png", 32),
  ("macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_64.png", 64),
  ("macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_128.png", 128),
  ("macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_256.png", 256),
  ("macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_512.png", 512),
  ("macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_1024.png", 1024),
]

for (relativePath, size) in outputs {
  let destination = projectRoot.appendingPathComponent(relativePath)
  try fileManager.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)

  let process = Process()
  process.executableURL = URL(fileURLWithPath: "/usr/bin/sips")
  process.arguments = [
    "-z", String(size), String(size),
    sourceURL.path,
    "--out", destination.path,
  ]
  try process.run()
  process.waitUntilExit()

  if process.terminationStatus != 0 {
    fputs("Failed to resize icon for \(relativePath)\n", stderr)
    exit(1)
  }
}

print("Generated app icon source: \(sourceURL.path)")