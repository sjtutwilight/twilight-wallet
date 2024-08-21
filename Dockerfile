# Use an official Node.js runtime as a parent image
# FROM node:20

# # Set the working directory in the container
# WORKDIR /usr/src/app

# # Copy the package.json and package-lock.json
# COPY package*.json ./

# # Install dependencies
# RUN npm install

# # Copy the rest of the application files
# COPY . .

# # Expose the port that Hardhat node will use
# EXPOSE 8545

# # Command to run the Hardhat node
# CMD ["npx", "hardhat", "node"]