import { describe, it, expect, beforeEach } from "vitest";
import { Cl } from "@stacks/transactions";
import type { Account } from "@hirosystems/clarinet-sdk";

const accounts = simnet.getAccounts();
const deployerAddress = accounts.get("deployer")!;
const wallet1Address = accounts.get("wallet_1")!;
const wallet2Address = accounts.get("wallet_2")!;

describe("DAO Credential Contract", () => {
  beforeEach(() => {
    simnet.initContract('dao-credential', 'contracts/dao-credential.clar', deployerAddress);
  });

  describe("DAO Membership", () => {
    it("should allow users to join DAO with minimum stake", () => {
      const joinResult = simnet.callPublicFn(
        'dao-credential',
        'join-dao',
        [Cl.uint(1000)],
        wallet1Address
      );

      expect(joinResult.result).toBeOk(Cl.bool(true));

      // Check member was added
      const memberResult = simnet.callReadOnlyFn(
        'dao-credential',
        'get-member',
        [Cl.principal(wallet1Address)],
        deployerAddress
      );

      expect(memberResult.result).toBeOk(
        Cl.some(
          Cl.tuple({
            stake: Cl.uint(1000),
            reputation: Cl.uint(100),
            'join-date': Cl.uint(simnet.blockHeight),
            'courses-completed': Cl.uint(0),
            'badges-earned': Cl.uint(1) // New Member badge awarded
          })
        )
      );
    });

    it("should reject insufficient stake", () => {
      const joinResult = simnet.callPublicFn(
        'dao-credential',
        'join-dao',
        [Cl.uint(500)],
        wallet1Address
      );

      expect(joinResult.result).toBeErr(Cl.uint(108)); // ERR-NOT-ENOUGH-STAKE
    });

    it("should prevent duplicate membership", () => {
      // First join should succeed
      simnet.callPublicFn('dao-credential', 'join-dao', [Cl.uint(1000)], wallet1Address);

      // Second join should fail
      const secondJoinResult = simnet.callPublicFn(
        'dao-credential',
        'join-dao',
        [Cl.uint(1000)],
        wallet1Address
      );

      expect(secondJoinResult.result).toBeErr(Cl.uint(101)); // ERR-ALREADY-MEMBER
    });
  });

  describe("Achievement Badge System", () => {
    beforeEach(() => {
      // Setup DAO membership for testing
      simnet.callPublicFn('dao-credential', 'join-dao', [Cl.uint(1000)], wallet1Address);
    });

    it("should award New Member badge on joining", () => {
      const badgeResult = simnet.callReadOnlyFn(
        'dao-credential',
        'get-user-badge',
        [Cl.principal(wallet1Address), Cl.uint(1)],
        deployerAddress
      );

      expect(badgeResult.result).toBeOk(
        Cl.some(
          Cl.tuple({
            'earned-date': Cl.uint(simnet.blockHeight),
            verified: Cl.bool(true)
          })
        )
      );
    });

    it("should display correct badge definition", () => {
      const badgeDefResult = simnet.callReadOnlyFn(
        'dao-credential',
        'get-badge-definition',
        [Cl.uint(1)],
        deployerAddress
      );

      expect(badgeDefResult.result).toBeOk(
        Cl.some(
          Cl.tuple({
            name: Cl.stringAscii("New Member"),
            description: Cl.stringAscii("Welcome to the DAO! Awarded for joining the community."),
            'badge-type': Cl.stringAscii("membership"),
            'requirement-value': Cl.uint(1),
            'icon-uri': Cl.stringAscii("ipfs://QmNewMemberBadge"),
            active: Cl.bool(true)
          })
        )
      );
    });

    it("should count user badges correctly", () => {
      const badgeCountResult = simnet.callReadOnlyFn(
        'dao-credential',
        'get-user-badges-count',
        [Cl.principal(wallet1Address)],
        deployerAddress
      );

      expect(badgeCountResult.result).toBeOk(Cl.uint(1)); // New Member badge
    });

    it("should allow DAO owner to create custom badges", () => {
      const createBadgeResult = simnet.callPublicFn(
        'dao-credential',
        'create-custom-badge',
        [
          Cl.stringAscii("Expert Reviewer"),
          Cl.stringAscii("Awarded for reviewing 10+ course submissions with quality feedback."),
          Cl.stringAscii("special"),
          Cl.uint(10),
          Cl.stringAscii("ipfs://QmExpertReviewerBadge")
        ],
        deployerAddress
      );

      expect(createBadgeResult.result).toBeOk(Cl.uint(6)); // Next badge ID

      // Verify badge was created
      const badgeDefResult = simnet.callReadOnlyFn(
        'dao-credential',
        'get-badge-definition',
        [Cl.uint(6)],
        deployerAddress
      );

      expect(badgeDefResult.result).toBeOk(
        Cl.some(
          Cl.tuple({
            name: Cl.stringAscii("Expert Reviewer"),
            description: Cl.stringAscii("Awarded for reviewing 10+ course submissions with quality feedback."),
            'badge-type': Cl.stringAscii("special"),
            'requirement-value': Cl.uint(10),
            'icon-uri': Cl.stringAscii("ipfs://QmExpertReviewerBadge"),
            active: Cl.bool(true)
          })
        )
      );
    });

    it("should prevent non-owner from creating badges", () => {
      const createBadgeResult = simnet.callPublicFn(
        'dao-credential',
        'create-custom-badge',
        [
          Cl.stringAscii("Unauthorized Badge"),
          Cl.stringAscii("This should fail."),
          Cl.stringAscii("special"),
          Cl.uint(1),
          Cl.stringAscii("ipfs://QmUnauthorized")
        ],
        wallet1Address
      );

      expect(createBadgeResult.result).toBeErr(Cl.uint(100)); // ERR-NOT-AUTHORIZED
    });

    it("should award Course Creator badge on course submission", () => {
      const submitResult = simnet.callPublicFn(
        'dao-credential',
        'submit-course',
        [
          Cl.stringAscii("Web3 Fundamentals"),
          Cl.stringAscii("ipfs://QmWeb3Course")
        ],
        wallet1Address
      );

      expect(submitResult.result).toBeOk(Cl.uint(1));

      // Check Course Creator badge was awarded
      const badgeResult = simnet.callReadOnlyFn(
        'dao-credential',
        'get-user-badge',
        [Cl.principal(wallet1Address), Cl.uint(2)],
        deployerAddress
      );

      expect(badgeResult.result).toBeOk(
        Cl.some(
          Cl.tuple({
            'earned-date': Cl.uint(simnet.blockHeight),
            verified: Cl.bool(true)
          })
        )
      );

      // Badge count should now be 2
      const badgeCountResult = simnet.callReadOnlyFn(
        'dao-credential',
        'get-user-badges-count',
        [Cl.principal(wallet1Address)],
        deployerAddress
      );

      expect(badgeCountResult.result).toBeOk(Cl.uint(2));
    });
  });

  describe("Course Management", () => {
    beforeEach(() => {
      simnet.callPublicFn('dao-credential', 'join-dao', [Cl.uint(1000)], wallet1Address);
      simnet.callPublicFn('dao-credential', 'join-dao', [Cl.uint(1000)], wallet2Address);
    });

    it("should allow members to submit courses", () => {
      const submitResult = simnet.callPublicFn(
        'dao-credential',
        'submit-course',
        [
          Cl.stringAscii("Blockchain Basics"),
          Cl.stringAscii("ipfs://QmBlockchainCourse")
        ],
        wallet1Address
      );

      expect(submitResult.result).toBeOk(Cl.uint(1));

      const courseResult = simnet.callReadOnlyFn(
        'dao-credential',
        'get-course',
        [Cl.uint(1)],
        deployerAddress
      );

      expect(courseResult.result).toBeOk(
        Cl.some(
          Cl.tuple({
            creator: Cl.principal(wallet1Address),
            name: Cl.stringAscii("Blockchain Basics"),
            'content-uri': Cl.stringAscii("ipfs://QmBlockchainCourse"),
            status: Cl.stringAscii("voting"),
            'votes-for': Cl.uint(0),
            'votes-against': Cl.uint(0),
            'voting-ends-at': Cl.uint(simnet.blockHeight + 144),
            approved: Cl.bool(false)
          })
        )
      );
    });

    it("should allow voting on courses and award Active Voter badge", () => {
      // Submit a course
      simnet.callPublicFn(
        'dao-credential',
        'submit-course',
        [Cl.stringAscii("Test Course"), Cl.stringAscii("ipfs://QmTest")],
        wallet1Address
      );

      // Vote on the course
      const voteResult = simnet.callPublicFn(
        'dao-credential',
        'vote-on-course',
        [Cl.uint(1), Cl.bool(true)],
        wallet2Address
      );

      expect(voteResult.result).toBeOk(Cl.bool(true));

      // Check Active Voter badge was awarded
      const badgeResult = simnet.callReadOnlyFn(
        'dao-credential',
        'get-user-badge',
        [Cl.principal(wallet2Address), Cl.uint(3)],
        deployerAddress
      );

      expect(badgeResult.result).toBeOk(
        Cl.some(
          Cl.tuple({
            'earned-date': Cl.uint(simnet.blockHeight),
            verified: Cl.bool(true)
          })
        )
      );
    });

    it("should prevent non-members from submitting courses", () => {
      const nonMemberAddress = accounts.get("wallet_3")!;
      
      const submitResult = simnet.callPublicFn(
        'dao-credential',
        'submit-course',
        [
          Cl.stringAscii("Unauthorized Course"),
          Cl.stringAscii("ipfs://QmUnauthorized")
        ],
        nonMemberAddress
      );

      expect(submitResult.result).toBeErr(Cl.uint(102)); // ERR-NOT-MEMBER
    });
  });

  describe("Course Enrollment and Credentials", () => {
    beforeEach(() => {
      simnet.callPublicFn('dao-credential', 'join-dao', [Cl.uint(1000)], wallet1Address);
      simnet.callPublicFn('dao-credential', 'join-dao', [Cl.uint(1000)], wallet2Address);
      
      // Create and approve a course
      simnet.callPublicFn(
        'dao-credential',
        'submit-course',
        [Cl.stringAscii("Approved Course"), Cl.stringAscii("ipfs://QmApproved")],
        wallet1Address
      );
      
      // Vote to approve
      simnet.callPublicFn('dao-credential', 'vote-on-course', [Cl.uint(1), Cl.bool(true)], wallet2Address);
      
      // Advance blocks to end voting period
      simnet.mineEmptyBlocks(150);
      
      // Finalize course
      simnet.callPublicFn('dao-credential', 'finalize-course', [Cl.uint(1)], deployerAddress);
    });

    it("should allow course enrollment", () => {
      const enrollResult = simnet.callPublicFn(
        'dao-credential',
        'enroll-in-course',
        [Cl.uint(1)],
        wallet2Address
      );

      expect(enrollResult.result).toBeOk(Cl.bool(true));

      const enrollmentResult = simnet.callReadOnlyFn(
        'dao-credential',
        'is-enrolled',
        [Cl.uint(1), Cl.principal(wallet2Address)],
        deployerAddress
      );

      expect(enrollmentResult.result).toBeOk(Cl.bool(true));
    });

    it("should mint credentials and award Course Graduate badge", () => {
      // Enroll in course
      simnet.callPublicFn('dao-credential', 'enroll-in-course', [Cl.uint(1)], wallet2Address);
      
      // Mint credential
      const mintResult = simnet.callPublicFn(
        'dao-credential',
        'mint-credential',
        [Cl.uint(1), Cl.principal(wallet2Address)],
        deployerAddress
      );

      expect(mintResult.result).toBeOk(Cl.uint(1));

      // Check credential was created
      const credentialResult = simnet.callReadOnlyFn(
        'dao-credential',
        'get-credential',
        [Cl.uint(1)],
        deployerAddress
      );

      expect(credentialResult.result).toBeOk(
        Cl.some(
          Cl.tuple({
            recipient: Cl.principal(wallet2Address),
            'course-id': Cl.uint(1),
            timestamp: Cl.uint(simnet.blockHeight)
          })
        )
      );

      // Check Course Graduate badge was awarded
      const badgeResult = simnet.callReadOnlyFn(
        'dao-credential',
        'get-user-badge',
        [Cl.principal(wallet2Address), Cl.uint(4)],
        deployerAddress
      );

      expect(badgeResult.result).toBeOk(
        Cl.some(
          Cl.tuple({
            'earned-date': Cl.uint(simnet.blockHeight),
            verified: Cl.bool(true)
          })
        )
      );

      // Check member's course completion count was updated
      const memberResult = simnet.callReadOnlyFn(
        'dao-credential',
        'get-member',
        [Cl.principal(wallet2Address)],
        deployerAddress
      );

      const memberData = memberResult.result.expectOk().expectSome();
      expect(memberData["courses-completed"]).toEqual(Cl.uint(1));
    });
  });

  describe("Error Handling", () => {
    it("should handle invalid badge types", () => {
      const createBadgeResult = simnet.callPublicFn(
        'dao-credential',
        'create-custom-badge',
        [
          Cl.stringAscii("Invalid Badge"),
          Cl.stringAscii("This has an invalid type."),
          Cl.stringAscii("invalid-type"),
          Cl.uint(1),
          Cl.stringAscii("ipfs://QmInvalid")
        ],
        deployerAddress
      );

      expect(createBadgeResult.result).toBeErr(Cl.uint(116)); // ERR-INVALID-BADGE-TYPE
    });

    it("should prevent duplicate badge awards", () => {
      // Join DAO (gets New Member badge)
      simnet.callPublicFn('dao-credential', 'join-dao', [Cl.uint(1000)], wallet1Address);

      // Try to manually award the same badge again
      const awardResult = simnet.callPublicFn(
        'dao-credential',
        'award-special-badge',
        [Cl.principal(wallet1Address), Cl.uint(1)],
        deployerAddress
      );

      // This should fail because badge 1 is not of type "special"
      expect(awardResult.result).toBeErr(Cl.uint(116)); // ERR-INVALID-BADGE-TYPE
    });
  });
});
