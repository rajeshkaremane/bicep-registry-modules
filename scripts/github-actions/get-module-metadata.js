import { CreatePullRequestHelper } from "./create-pull-request-helper.js";
import fs from "fs";
import path from "path";
import axios from "axios";
/**
 * @param {typeof import("fs")} fs
 * @param {string} dir
 */
function getSubdirNames(fs, dir) {
  return fs
    .readdirSync(dir, { withFileTypes: true })
    .filter((x) => x.isDirectory())
    .map((x) => x.name);
}

async function getModuleMetadata({ github, context, core }) {

  const moduleGroups = getSubdirNames(fs, "modules");
  var result = {};

  for (const moduleGroup of moduleGroups) {
    var moduleGroupPath = path.join("modules", moduleGroup);
    var moduleNames = getSubdirNames(fs, moduleGroupPath);

    for (const moduleName of moduleNames) {
      const modulePath = `${moduleGroup}/${moduleName}`;
      const versionListUrl = `https://mcr.microsoft.com/v2/bicep/${modulePath}/tags/list`;

      try {
        const versionListResponse = await axios.default.get(versionListUrl);
        const tags = versionListResponse.data.tags.sort();

        result[modulePath] = tags;
      } catch (error) {
        core.setFailed(error);
      }
    }
  }

  const oldModuleMetadata = fs.readFileSync("moduleMetadata.json", {
    encoding: "utf-8",
  });
  const newModuleMetadata = JSON.stringify(result, null, 2);

  if (oldModuleMetadata === newModuleMetadata) {
    core.info("The module names with tags information is up to date.");
    return;
  }

  const createPRHelper = new CreatePullRequestHelper(
    "dev/bhsubra/CreateBicepRegistryModuleReferences", 
    "refresh-module-metadata",
    newModuleMetadata,
    context,
    github,
    "Refresh module metadata",
    "moduleMetadata.json",
    "Refresh bicep registry module references"
    );
    const url = await createPRHelper.createPullRequest();

  core.info(
    `The module metadata is outdated. A pull request ${url} was created to update it.`
  );
}

module.exports = getModuleMetadata;