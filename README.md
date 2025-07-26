# Pixel Art Creator NFT

A Clarity-based NFT contract for creating and trading pixel art on the Stacks blockchain.

## Features

- Mint NFTs with custom pixel art data
- Built-in royalty system (up to 25%)
- Metadata tracking including creator and creation block
- Standard NFT trait compliance
- Configurable base URI for metadata

## Contract Functions

### Public Functions
- `mint-pixel-art`: Create a new pixel art NFT
- `transfer`: Transfer NFT ownership
- `set-base-uri`: Update metadata base URI (owner only)

### Read-Only Functions
- `get-last-token-id`: Get the latest minted token ID
- `get-token-uri`: Get metadata URI for a token
- `get-owner`: Get current owner of a token
- `get-token-metadata`: Get full metadata for a token

## Usage

Deploy the contract and call `mint-pixel-art` with recipient address, pixel data string, and royalty percentage to create new NFTs.