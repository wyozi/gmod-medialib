workflow "Build" {
  on = "release"
  resolves = ["Upload .lua", "Upload .min.lua"]
}

action "Build distributable" {
  uses = "./builder"
}

action "Upload .lua" {
  uses = "JasonEtco/upload-to-release@master"
  args = "dist/medialib.lua"
  secrets = ["GITHUB_TOKEN"]
  needs = ["Build distributable"]
}
action "Upload .min.lua" {
  uses = "JasonEtco/upload-to-release@master"
  args = "dist/medialib.min.lua"
  secrets = ["GITHUB_TOKEN"]
  needs = ["Build distributable"]
}