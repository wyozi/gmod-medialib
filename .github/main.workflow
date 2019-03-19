workflow "Build" {
  on = "release"
  resolves = ["Upload .lua", "Upload .min.lua"]
}

action "Build distributable" {
  uses = "./builder"
}

action "Upload .lua" {
  uses = "JasonEtco/upload-to-release@master"
  args = "dist/medialib.lua application/x-lua"
  secrets = ["GITHUB_TOKEN"]
  needs = ["Build distributable"]
}

action "Upload .min.lua" {
  uses = "JasonEtco/upload-to-release@master"
  args = "dist/medialib.min.lua application/x-lua"
  secrets = ["GITHUB_TOKEN"]
  needs = ["Build distributable"]
}

workflow "Check" {
    on = "push"
    resolves = ["Luacheck"]
}

action "Luacheck" {
    uses = "wyozi/luacheck-action@master"
    args = "lua -g --no-self --ignore 212/_.* --ignore 211/_.* --ignore 213/_.*"
}