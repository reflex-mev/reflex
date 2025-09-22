import { REFLEX_ROUTER_ABI } from "../src/constants/abi";

describe("Constants", () => {
  describe("REFLEX_ROUTER_ABI", () => {
    it("should contain all required functions", () => {
      const functionNames = REFLEX_ROUTER_ABI.filter(
        (item) => item.type === "function"
      ).map((item) => item.name);

      expect(functionNames).toContain("backrunedExecute");
      expect(functionNames).toContain("triggerBackrun");
      expect(functionNames).toContain("getReflexAdmin");
      expect(functionNames).toContain("reflexQuoter");
      expect(functionNames).toContain("setReflexQuoter");
      expect(functionNames).toContain("withdrawToken");
      expect(functionNames).toContain("withdrawEth");
    });

    it("should contain BackrunExecuted event", () => {
      const events = REFLEX_ROUTER_ABI.filter((item) => item.type === "event");
      const eventNames = events.map((item) => item.name);

      expect(eventNames).toContain("BackrunExecuted");
    });

    it("should have correct backrunedExecute function signature", () => {
      const backrunedExecute = REFLEX_ROUTER_ABI.find(
        (item) => item.type === "function" && item.name === "backrunedExecute"
      );

      expect(backrunedExecute).toBeDefined();
      expect(backrunedExecute?.inputs).toHaveLength(2);
      expect(backrunedExecute?.outputs).toHaveLength(4);
      expect(backrunedExecute?.stateMutability).toBe("payable");
    });

    it("should have correct triggerBackrun function signature", () => {
      const triggerBackrun = REFLEX_ROUTER_ABI.find(
        (item) => item.type === "function" && item.name === "triggerBackrun"
      );

      expect(triggerBackrun).toBeDefined();
      expect(triggerBackrun?.inputs).toHaveLength(5); // Updated to include configId
      expect(triggerBackrun?.outputs).toHaveLength(2);
      expect(triggerBackrun?.stateMutability).toBe("nonpayable");
    });

    it("should have fallback and receive functions", () => {
      const fallback = REFLEX_ROUTER_ABI.find(
        (item) => item.type === "fallback"
      );
      const receive = REFLEX_ROUTER_ABI.find((item) => item.type === "receive");

      expect(fallback).toBeDefined();
      expect(receive).toBeDefined();
      expect(fallback?.stateMutability).toBe("payable");
      expect(receive?.stateMutability).toBe("payable");
    });
  });
});
