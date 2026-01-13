// @ts-check
// `@type` JSDoc annotations allow editor autocompletion and type checking
// (when paired with `@ts-check`).
// There are various equivalent ways to declare your Docusaurus config.
// See: https://docusaurus.io/docs/api/docusaurus-config

import { themes as prismThemes } from "prism-react-renderer";

/** @type {import('@docusaurus/types').Config} */
const config = {
  title: "Reflex",
  tagline: "Advanced MEV Infrastructure for DeFi",
  favicon: "img/favicon.ico",

  // Set the production url of your site here
  url: "https://reflex-mev.github.io",
  // Set the /<baseUrl>/ pathname under which your site is served
  // For GitHub pages deployment, it is often '/<projectName>/'
  baseUrl: process.env.NODE_ENV === "production" ? "/" : "/",

  // GitHub pages deployment config.
  // If you aren't using GitHub pages, you don't need these.
  organizationName: "reflex-mev", // Usually your GitHub org/user name.
  projectName: "reflex", // Usually your repo name.

  // Custom deployment configuration for SSH host alias
  deploymentBranch: "gh-pages",
  trailingSlash: false,

  onBrokenLinks: "throw",
  onBrokenMarkdownLinks: "warn",

  // Even if you don't use internationalization, you can use this field to set
  // useful metadata like html lang. For example, if your site is Chinese, you
  // may want to set this to `zh-Hans`.
  i18n: {
    defaultLocale: "en",
    locales: ["en"],
  },

  markdown: {
    mermaid: true,
  },
  themes: ["@docusaurus/theme-mermaid"],

  presets: [
    [
      "classic",
      /** @type {import('@docusaurus/preset-classic').Options} */
      ({
        docs: {
          sidebarPath: "./sidebars.js",
          routeBasePath: "/", // Serve the docs at the site's root
          // Please change this to your repo.
          // Remove this to remove the "edit this page" links.
          editUrl: "https://github.com/reflex-mev/reflex/tree/main/website/",
        },
        blog: false,
        theme: {
          customCss: "./src/css/custom.css",
        },
      }),
    ],
  ],

  themeConfig:
    /** @type {import('@docusaurus/preset-classic').ThemeConfig} */
    ({
      // Replace with your project's social card
      image: "img/reflex-social-card.jpg",
      navbar: {
        title: "Reflex",
        logo: {
          alt: "Reflex Logo",
          src: "img/min_logo_2.png",
        },
        items: [
          {
            href: "https://github.com/reflex-mev/reflex",
            label: "GitHub",
            position: "right",
          },
        ],
      },
      footer: {
        style: "dark",
        links: [
          {
            title: "Docs",
            items: [
              {
                label: "Integration Guide",
                to: "/integration/overview",
              },
              {
                label: "API Reference",
                to: "/api/reflex-router",
              },
              {
                label: "Security",
                to: "/security/overview",
              },
            ],
          },
          {
            title: "Community",
            items: [
              {
                label: "Twitter/X",
                href: "https://x.com/ReflexMEV",
              },
            ],
          },
          {
            title: "More",
            items: [
              {
                label: "GitHub",
                href: "https://github.com/reflex-mev/reflex",
              },
            ],
          },
        ],
        copyright: `Copyright © ${new Date().getFullYear()} Reflex. Built with Docusaurus.`,
      },
      prism: {
        theme: prismThemes.github,
        darkTheme: prismThemes.dracula,
        additionalLanguages: ["solidity"],
      },
    }),
};

export default config;
