import {
  isValidAddress,
  isValidBytes32,
  formatTokenAmount,
  parseTokenAmount,
  calculateProfitPercentage,
} from "../src/utils";

describe("Utils", () => {
  describe("isValidAddress", () => {
    it("should validate correct Ethereum addresses", () => {
      expect(isValidAddress("0x1234567890123456789012345678901234567890")).toBe(
        true
      );
      expect(isValidAddress("0xA0b86a33E6441e8DD31e74c518e7b8B1C62b8e80")).toBe(
        true
      );
    });

    it("should reject invalid addresses", () => {
      expect(isValidAddress("0x123")).toBe(false);
      expect(isValidAddress("1234567890123456789012345678901234567890")).toBe(
        false
      );
      expect(isValidAddress("0xG234567890123456789012345678901234567890")).toBe(
        false
      );
      expect(isValidAddress("")).toBe(false);
    });
  });

  describe("isValidBytes32", () => {
    it("should validate correct bytes32 values", () => {
      expect(
        isValidBytes32(
          "0x1234567890123456789012345678901234567890123456789012345678901234"
        )
      ).toBe(true);
      expect(
        isValidBytes32(
          "0x0000000000000000000000000000000000000000000000000000000000000000"
        )
      ).toBe(true);
    });

    it("should reject invalid bytes32 values", () => {
      expect(isValidBytes32("0x123")).toBe(false);
      expect(
        isValidBytes32(
          "1234567890123456789012345678901234567890123456789012345678901234"
        )
      ).toBe(false);
      expect(
        isValidBytes32(
          "0xG234567890123456789012345678901234567890123456789012345678901234"
        )
      ).toBe(false);
      expect(isValidBytes32("")).toBe(false);
    });
  });

  describe("formatTokenAmount", () => {
    it("should format token amounts correctly", () => {
      expect(formatTokenAmount(BigInt("1000000000000000000"))).toBe("1");
      expect(formatTokenAmount(BigInt("1500000000000000000"))).toBe("1.5");
      expect(formatTokenAmount(BigInt("123456789012345678"))).toBe(
        "0.123456789012345678"
      );
      expect(formatTokenAmount(BigInt("1000000"), 6)).toBe("1");
    });

    it("should handle zero values", () => {
      expect(formatTokenAmount(BigInt("0"))).toBe("0");
    });

    it("should trim trailing zeros", () => {
      expect(formatTokenAmount(BigInt("1100000000000000000"))).toBe("1.1");
      expect(formatTokenAmount(BigInt("1000000000000000000"))).toBe("1");
    });
  });

  describe("parseTokenAmount", () => {
    it("should parse token amounts correctly", () => {
      expect(parseTokenAmount("1")).toBe(BigInt("1000000000000000000"));
      expect(parseTokenAmount("1.5")).toBe(BigInt("1500000000000000000"));
      expect(parseTokenAmount("0.123456789012345678")).toBe(
        BigInt("123456789012345678")
      );
      expect(parseTokenAmount("1", 6)).toBe(BigInt("1000000"));
    });

    it("should handle edge cases", () => {
      expect(parseTokenAmount("0")).toBe(BigInt("0"));
      expect(parseTokenAmount("0.0")).toBe(BigInt("0"));
      expect(parseTokenAmount("1.")).toBe(BigInt("1000000000000000000"));
    });
  });

  describe("calculateProfitPercentage", () => {
    it("should calculate profit percentage correctly", () => {
      expect(calculateProfitPercentage(BigInt("100"), BigInt("1000"))).toBe(10);
      expect(calculateProfitPercentage(BigInt("50"), BigInt("1000"))).toBe(5);
      expect(calculateProfitPercentage(BigInt("1"), BigInt("100"))).toBe(1);
    });

    it("should handle zero investment", () => {
      expect(calculateProfitPercentage(BigInt("100"), BigInt("0"))).toBe(0);
    });

    it("should handle zero profit", () => {
      expect(calculateProfitPercentage(BigInt("0"), BigInt("1000"))).toBe(0);
    });
  });
});
