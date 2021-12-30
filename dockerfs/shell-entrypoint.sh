#!/bin/bash

poetry update
poetry run brownie pm install OpenZeppelin/openzeppelin-contracts@4.3.0

cd /registry/contracts
poetry run brownie compile --all

cd /registry

poetry shell
