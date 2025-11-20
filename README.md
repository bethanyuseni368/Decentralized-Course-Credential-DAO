# 🎓 Decentralized Course Credential DAO with Achievement Badge System

A decentralized autonomous organization (DAO) for course accreditation and credential issuance on the Stacks blockchain, enhanced with a comprehensive Achievement Badge System to gamify learning and community participation.

## 🌟 Features

### Core DAO Features
- DAO membership with STX staking
- Course submission and review system 
- Decentralized voting mechanism
- NFT credential minting
- Reputation tracking
- Course enrollment system
- Course rating and feedback system

### 🏆 NEW: Achievement Badge System
- **Automatic Badge Awards**: Members earn badges automatically based on their activities
- **Custom Badge Creation**: DAO owners can create special badges for community milestones
- **Badge Types**: membership, creation, governance, achievement, and special badges
- **Progress Tracking**: Track courses completed and badges earned
- **Gamification**: Encourage participation through achievement unlocks

## 🏅 Available Badges

### Default Badges
1. **New Member** - Welcome to the DAO! Awarded for joining the community
2. **Course Creator** - Awarded for submitting your first course for review
3. **Active Voter** - Participated in governance by voting on course proposals
4. **Course Graduate** - Successfully completed your first approved course
5. **Scholar** - Completed 5 approved courses - true dedication to learning!

### Custom Badges
DAO owners can create additional badges with custom requirements and reward special community contributions.

## 🔧 Smart Contract Functions

### DAO Management
- `initialize-dao`: Set DAO owner and initialize badge system
- `join-dao`: Join DAO by staking STX (awards New Member badge)

### Course Management
- `submit-course`: Submit new course for review (awards Course Creator badge)
- `vote-on-course`: Vote on course approval (awards Active Voter badge)
- `finalize-course`: Complete voting process
- `enroll-in-course`: Enroll in approved courses
- `rate-course`: Rate completed courses (1-5 stars)

### Credentials & Achievements
- `mint-credential`: Mint NFT credential for approved courses (awards Course Graduate badge)
- `create-custom-badge`: Create new badge types (DAO owner only)
- `award-special-badge`: Manually award special badges (DAO owner only)

### Read-Only Functions
- `get-course`: Get course details
- `get-member`: Get DAO member info including badge count
- `get-credential`: Get credential details
- `get-badge-definition`: Get badge information
- `get-user-badge`: Check if user has specific badge
- `get-user-badges-count`: Get total badges earned by user
- `get-course-rating`: Get average course rating
- `is-enrolled`: Check course enrollment status

## 🚀 Getting Started

1. Install [Clarinet](https://github.com/hirosystems/clarinet)
2. Clone this repository
3. Install dependencies: `npm install`
4. Run contract checks: `clarinet check`
5. Run tests: `npm test`

## 💡 Usage Example

```clarity
;; Join DAO (automatically awards New Member badge)
(contract-call? .dao-credential join-dao u1000)

;; Submit course (automatically awards Course Creator badge)  
(contract-call? .dao-credential submit-course "Web3 Basics" "ipfs://Qm...")

;; Vote on course (automatically awards Active Voter badge)
(contract-call? .dao-credential vote-on-course u1 true)

;; Enroll in approved course
(contract-call? .dao-credential enroll-in-course u1)

;; Mint credential after completion (automatically awards Course Graduate badge)
(contract-call? .dao-credential mint-credential u1 'ST1HTBVD3JG9C05J7HBJTHGR0GGW7KXW28M5JS8QE)

;; Check user's badges
(contract-call? .dao-credential get-user-badges-count 'ST1HTBVD3JG9C05J7HBJTHGR0GGW7KXW28M5JS8QE)

;; Create custom badge (DAO owner only)
(contract-call? .dao-credential create-custom-badge 
  "Expert Reviewer" 
  "Awarded for reviewing 10+ courses with quality feedback"
  "special"
  u10
  "ipfs://QmExpertBadge")
```

## 🏆 Achievement Progress

The badge system tracks member progress and automatically awards achievements:

- **Join the DAO** → New Member Badge
- **Submit First Course** → Course Creator Badge  
- **Vote on Proposals** → Active Voter Badge
- **Complete First Course** → Course Graduate Badge
- **Complete 5 Courses** → Scholar Badge
- **Special Contributions** → Custom Badges (manually awarded)

## 🔒 Security Features

- Minimum stake requirement for DAO membership
- Voting period restrictions
- Authorization checks for critical functions
- Badge award validation and duplicate prevention
- Proper error handling with descriptive error codes

## 🧪 Testing

The contract includes comprehensive tests covering:
- DAO membership and staking
- Badge award mechanics
- Course lifecycle management
- Error handling scenarios
- Access control validation

## 📊 Technical Implementation

### Achievement Badge System Architecture
- **Badge Definitions**: Metadata for each badge type with requirements
- **User Badges**: Tracking individual badge awards with timestamps
- **Automatic Awards**: Built-in logic to award badges on qualifying actions
- **Custom Creation**: Flexible system for community-specific badges
- **Progress Tracking**: Enhanced member profiles with achievement data

### Clarity v3 Features
- Proper error constants and handling
- Comprehensive data validation
- Gas-efficient map structures
- NFT trait implementation for credentials

## 🤝 Contributing

1. Fork the repository
2. Create feature branch (`git checkout -b feature/amazing-feature`)
3. Run tests (`npm test`)
4. Commit changes (`git commit -m 'Add amazing feature'`)
5. Push to branch (`git push origin feature/amazing-feature`)
6. Open Pull Request

## 📜 License

MIT License - see [LICENSE](LICENSE) file for details.

---

**Built with ❤️ for the Stacks ecosystem and decentralized education**
