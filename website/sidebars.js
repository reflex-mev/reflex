/**
 * Creating a sidebar enables you to:
 - create an ordered group of docs
 - render a sidebar for each doc of that group
 - provide next/previous navigation

 The sidebars can be generated from the filesystem, or explicitly defined here.

 Create as many sidebars as you want.
 */

// @ts-check

/** @type {import('@docusaurus/plugin-content-docs').SidebarsConfig} */
const sidebars = {
  // By default, Docusaurus generates a sidebar from the docs folder structure
  tutorialSidebar: [
    "index",
    "architecture",
    {
      type: "category",
      label: "Integrations",
      items: [
        "integration/overview",
        "integration/plugin-based",
        "integration/universal-dex",
        "integration/direct-access",
      ],
    },
    {
      type: "category",
      label: "API Reference",
      items: [
        {
          type: "category",
          label: "Smart Contracts",
          items: [
            "api/reflex-router",
            "api/reflex-after-swap",
            "api/backrun-enabled-swap-proxy",
          ],
        },
        {
          type: "category",
          label: "SDK Reference",
          items: [
            {
              type: "category",
              label: "Integrations",
              items: [
                "api/sdk/universal-integration",
              ],
            },
          ],
        },
      ],
    },
    "security",
  ],
};

export default sidebars;
