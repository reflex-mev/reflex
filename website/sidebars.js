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
    {
      type: "category",
      label: "Technical Reference",
      items: [
        "technical/architecture",
        {
          type: "category",
          label: "Integrations",
          items: [
            "technical/integration/overview",
            "technical/integration/revenue-configuration",
            "technical/integration/smart-contract",
            "technical/integration/sdk-integration",
          ],
        },
        {
          type: "category",
          label: "API Reference",
          items: [
            "technical/api/smart-contracts",
            "technical/api/sdk-reference",
          ],
        },
        "technical/security",
        "troubleshooting",
      ],
    },
  ],
};

export default sidebars;
