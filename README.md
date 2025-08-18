# Farm-to-Table Traceability System

A blockchain-based traceability system for tracking food products from farm to consumer, built on the Stacks blockchain using Clarity smart contracts.

## Overview

The Farm2table smart contract provides a complete traceability solution that enables transparent tracking of food products throughout the entire supply chain. From initial harvest to final consumption, every step is recorded immutably on the blockchain.

## Core Features

- **Farm Registration**: Register farms with organic certification status and location data
- **Product Management**: Create and track food products with harvest and expiry dates
- **Batch Tracking**: Create traceable batches with real-time location and status updates
- **Supply Chain Transfers**: Transfer batches between handlers with complete audit trails
- **Certification Management**: Add and verify organic and other certifications
- **Authenticity Verification**: Verify product authenticity and origin at any point

## Contract Functions

### Public Functions

#### Farm Management
- `register-farm(name, location, organic)` - Register a new farm
- `deactivate-farm(farm-id)` - Deactivate an existing farm
- `authorize-certifier(certifier)` - Authorize certification bodies (owner only)

#### Product Management
- `add-product(farm-id, name, category, harvest-date, expiry-date, quantity, unit)` - Add new product
- `create-batch(product-id, quantity, initial-location)` - Create trackable batch

#### Supply Chain Operations
- `transfer-batch(batch-id, new-handler, new-location, status, notes)` - Transfer batch ownership
- `add-certification(farm-id, cert-type, issued-by, valid-until)` - Add certifications

### Read-Only Functions
- `get-farm(farm-id)` - Retrieve farm information
- `get-product(product-id)` - Retrieve product details
- `get-batch(batch-id)` - Retrieve batch information
- `get-certification(cert-id)` - Retrieve certification details
- `get-batch-history(batch-id, sequence)` - Retrieve batch transfer history
- `get-product-origin(product-id)` - Get product's farm origin details
- `verify-batch-authenticity(batch-id)` - Verify batch is authentic and not expired
- `is-farm-organic(farm-id)` - Check if farm has organic certification

## Usage Examples

### 1. Register a Farm
```clarity
(contract-call? .Farm2table register-farm "Green Valley Farm" "California, USA" true)
```

### 2. Add a Product
```clarity
(contract-call? .Farm2table add-product u1 "Organic Tomatoes" "Vegetables" u1640995200 u1643587200 u100 "kg")
```

### 3. Create a Batch
```clarity
(contract-call? .Farm2table create-batch u1 u50 "Farm Warehouse")
```

### 4. Transfer Batch
```clarity
(contract-call? .Farm2table transfer-batch u1 'SP1234... "Distribution Center" "in-transit" "Shipped to distributor")
```

### 5. Verify Product Authenticity
```clarity
(contract-call? .Farm2table verify-batch-authenticity u1)
```

## Data Structures

### Farm
- `farm-id`: Unique farm identifier
- `owner`: Farm owner principal
- `name`: Farm name (max 50 chars)
- `location`: Geographic location (max 100 chars)
- `certified-organic`: Organic certification status
- `registration-block`: Block when farm was registered
- `active`: Farm status

### Product
- `product-id`: Unique product identifier
- `farm-id`: Originating farm
- `name`: Product name (max 50 chars)
- `category`: Product category (max 30 chars)
- `harvest-date`: Harvest timestamp
- `expiry-date`: Expiration timestamp
- `quantity`: Amount produced
- `unit`: Unit of measurement

### Batch
- `batch-id`: Unique batch identifier
- `product-id`: Associated product
- `farm-id`: Originating farm
- `quantity`: Batch quantity
- `status`: Current status (harvested, processed, shipped, etc.)
- `current-location`: Current location
- `current-handler`: Current responsible party
- `created-at`: Creation timestamp
- `last-updated`: Last update timestamp

## Testing

Install dependencies and run tests:
```bash
npm install
npm test
```

## Deployment

Deploy using Clarinet:
```bash
clarinet deploy --testnet
```

## Security Features

- **Access Control**: Functions restricted to authorized users (farm owners, certifiers)
- **Data Integrity**: Immutable records once created
- **Authenticity Verification**: Built-in verification of batch authenticity
- **Audit Trail**: Complete history of all batch transfers and status changes

## Error Codes

- `u100`: Not authorized to perform action
- `u101`: Farm not found
- `u102`: Product not found
- `u103`: Invalid batch
- `u104`: Already exists
- `u105`: Invalid certification
- `u106`: Transfer not allowed
- `u107`: List operation failed
