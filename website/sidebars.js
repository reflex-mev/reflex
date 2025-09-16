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
        {
          type: "category",
          label: "Getting Started",
          items: [
            "technical/getting-started/installation",
            "technical/getting-started/quick-start",
          ],
        },
        {
          type: "category",
          label: "Architecture",
          items: ["technical/architecture/overview"],
        },
        {
          type: "category",
          label: "API Reference",
          items: [
            "technical/api/smart-contracts",
            "technical/api/sdk-reference",
          ],
        },
        {
          type: "category",
          label: "Integration",
          items: ["technical/integration/overview"],
        },
        {
          type: "category",
          label: "Examples",
          items: ["technical/examples/basic-backrun"],
        },
        {
          type: "category",
          label: "Security",
          items: ["technical/security/overview"],
        },
        "technical/troubleshooting",
      ],
    },
  ],
};

export default sidebars;
