# 🔧 Pipeline Maintenance DAO

A decentralized autonomous organization for transparent pipeline maintenance management on the Stacks blockchain.

## 🚀 Overview

The Pipeline Maintenance DAO enables field workers to report maintenance needs, allows DAO members to vote on proposals, and facilitates transparent STX payments to approved contractors.

## ✨ Key Features

- 📝 **Maintenance Reporting**: Field workers submit detailed maintenance reports
- 🗳️ **Democratic Voting**: DAO members vote on maintenance proposals
- 💰 **Transparent Payments**: Automatic STX releases to approved contractors
- 👥 **Role Management**: Distinct roles for DAO members, field workers, and contractors
- 🏦 **Treasury Management**: Secure fund management with transparent tracking

## 🏗️ Contract Structure

### Roles

- **DAO Members** 👑: Vote on proposals and manage the organization
- **Field Workers** 🔍: Report maintenance issues and needs
- **Contractors** 🔨: Execute approved maintenance work

### Workflow

1. **Report Submission** 📋: Field workers submit maintenance reports
2. **Voting Period** 🗳️: DAO members vote for 144 blocks (~24 hours)
3. **Approval** ✅: Reports need 66% approval to proceed
4. **Assignment** 🎯: Approved contractors are assigned to work
5. **Completion** ✔️: Contractors mark work as completed
6. **Payment** 💳: DAO releases STX payment to contractors

## 📖 Usage Instructions

### Setup

1. **Initialize DAO**
   ```clarity
   (contract-call? .pipeline-maintenance-dao initialize-dao)
   ```

2. **Fund Treasury** 💰
   ```clarity
   (contract-call? .pipeline-maintenance-dao fund-treasury u1000000)
   ```

3. **Add Members**
   ```clarity
   (contract-call? .pipeline-maintenance-dao add-dao-member 'SP1234... u50)
   (contract-call? .pipeline-maintenance-dao add-field-worker 'SP5678...)
   (contract-call? .pipeline-maintenance-dao add-contractor 'SP9012...)
   ```

### Maintenance Process

1. **Submit Report** 📝
   ```clarity
   (contract-call? .pipeline-maintenance-dao submit-maintenance-report 
     "Pipe Leak Section A" 
     "Critical leak detected in main pipeline section A requiring immediate attention"
     "GPS: 40.7128, -74.0060"
     u500000)
   ```

2. **Vote on Report** 🗳️
   ```clarity
   (contract-call? .pipeline-maintenance-dao vote-on-report u1 true)
   ```

3. **Finalize Voting** ⏰
   ```clarity
   (contract-call? .pipeline-maintenance-dao finalize-voting u1)
   ```

4. **Assign Contractor** 🎯
   ```clarity
   (contract-call? .pipeline-maintenance-dao assign-contractor u1 'SP-CONTRACTOR...)
   ```

5. **Complete Work** ✅
   ```clarity
   (contract-call? .pipeline-maintenance-dao complete-work u1)
   ```

6. **Release Payment** 💸
   ```clarity
   (contract-call? .pipeline-maintenance-dao release-payment u1)
   ```

### Query Functions

- **Check Report Status** 📊
  ```clarity
  (contract-call? .pipeline-maintenance-dao get-report u1)
  ```

- **View Treasury** 🏦
  ```clarity
  (contract-call? .pipeline-maintenance-dao get-treasury-balance)
  ```

- **Check DAO Stats** 📈
  ```clarity
  (contract-call? .pipeline-maintenance-dao get-dao-stats)
  ```

## 🔧 Configuration

- **Voting Period**: 144 blocks (~24 hours)
- **Approval Threshold**: 66% of votes
- **Maximum Report Amount**: 10,000,000 µSTX

## 🛡️ Security Features

- Role-based access control
- Voting period enforcement
- Duplicate vote prevention
- Treasury balance validation
- Payment completion tracking

## 🧪 Testing

Run tests with:
```bash
clarinet test
```

Check contract syntax:
```bash
clarinet check
```

## 📄 License

MIT License - Build the future of decentralized infrastructure! 🌟
