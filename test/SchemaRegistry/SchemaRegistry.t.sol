// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {ISchemaResolver} from "../../src/schema-resolver/ISchemaResolver.sol";
import {RecordRequest, Record, RecordRequestData} from "../../src/interfaces/IRecordRegistry.sol";
import {FieldDefinition, FieldType, Schema} from "../../src/interfaces/ISchemaRegistry.sol";
import {ProvenanceTest} from "../ProvenanceTest.sol";

contract SchemaRegistryTest is ProvenanceTest {
    // =============================================================
    //                           EVENTS
    // =============================================================

    // Schema
    event SchemaRegistered(bytes32 indexed uid, uint256 indexed originator);
    event SchemaUpdated(bytes32 indexed uid, uint256 numAddedFields);
    event SchemaFieldUpdated(bytes32 indexed uid, uint256 indexed fieldIndex);

    // Records
    event Attested(uint256 indexed originator, uint256 indexed registrar, bytes32 uid, bytes32 indexed schemaUID);

    // =============================================================
    //                           ERRORS
    // =============================================================

    // =============================================================
    //                   Constants / Immutables
    // =============================================================

    // =============================================================
    //                       constructor()
    // =============================================================

    // =============================================================
    //                       Receiving ETH
    // =============================================================

    function testFuzz_RevertWhenReceivingDirectPayment(address sender, uint256 amount) public {
        vm.deal(sender, amount);
        vm.expectRevert();
        vm.prank(sender);
        payable(address(schemaRegistry)).transfer(amount);
    }

    // =============================================================
    //                        register()
    // =============================================================

    function testFuzz_schemaRegister(address custody) public {
        // Bound inputs that need to be bound
        vm.assume(custody != address(0));

        // Register the custody as an originator.
        uint256 originatorId = _register(custody, "username");

        // TODO: Assert preconditions?

        FieldDefinition[] memory fields = new FieldDefinition[](4);
        fields[0] = FieldDefinition({
            fieldName: "accountId",
            fieldType: FieldType.ACCOUNT_ID,
            isArray: false,
            allowedSchemaIds: new bytes32[](0),
            enumValues: new string[](0)
        });

        fields[1] = FieldDefinition({
            fieldName: "displayName",
            fieldType: FieldType.STRING,
            isArray: false,
            allowedSchemaIds: new bytes32[](0),
            enumValues: new string[](0)
        });

        fields[2] = FieldDefinition({
            fieldName: "profilePictureURI",
            fieldType: FieldType.STRING,
            isArray: false,
            allowedSchemaIds: new bytes32[](0),
            enumValues: new string[](0)
        });

        string[] memory genderEnum = new string[](3);
        genderEnum[0] = "other";
        genderEnum[1] = "female";
        genderEnum[2] = "male";

        fields[3] = FieldDefinition({
            fieldName: "gender",
            fieldType: FieldType.ENUM,
            isArray: false,
            allowedSchemaIds: new bytes32[](0),
            enumValues: genderEnum
        });

        // Define a simple ProfileData schema
        string memory name = "Profile Data";
        // Schema memory profileData = Schema({
        //     uid: bytes32(0),
        //     ownerId: originatorId,
        //     name: name,
        //     fields: fields,
        //     resolver: ISchemaResolver(address(0)),
        //     revocable: true,
        //     updatable: true
        // });

        bytes32 expectedUID = _getSchemaUID(originatorId, name, bytes32(0));

        // Register the schema
        vm.expectEmit();
        emit SchemaRegistered({uid: expectedUID, originator: originatorId});

        vm.prank(custody);
        bytes32 schemaUID = schemaRegistry.register({
            name: name,
            fields: fields,
            revocable: true,
            updatable: true,
            resolver: ISchemaResolver(address(0)),
            salt: bytes32(0)
        });

        // Assert postconditions
        assertEq(schemaUID, expectedUID);

        Schema memory schema = schemaRegistry.getSchema(schemaUID);
        assertEq(schema.uid, expectedUID);
        assertEq(address(schema.resolver), address(0));
        assertEq(schema.revocable, true);

        assertEq(schema.fields.length, 4);

        assertEq(schema.fields[0].fieldName, "accountId");
        assertEq(uint256(schema.fields[0].fieldType), uint256(FieldType.ACCOUNT_ID));
        assertEq(schema.fields[0].isArray, false);
        assertEq(schema.fields[0].allowedSchemaIds.length, 0);
        assertEq(schema.fields[0].enumValues.length, 0);

        assertEq(schema.fields[1].fieldName, "displayName");
        assertEq(uint256(schema.fields[1].fieldType), uint256(FieldType.STRING));
        assertEq(schema.fields[1].isArray, false);
        assertEq(schema.fields[1].allowedSchemaIds.length, 0);
        assertEq(schema.fields[1].enumValues.length, 0);

        assertEq(schema.fields[2].fieldName, "profilePictureURI");
        assertEq(uint256(schema.fields[2].fieldType), uint256(FieldType.STRING));
        assertEq(schema.fields[2].isArray, false);
        assertEq(schema.fields[2].allowedSchemaIds.length, 0);
        assertEq(schema.fields[2].enumValues.length, 0);

        assertEq(schema.fields[3].fieldName, "gender");
        assertEq(uint256(schema.fields[3].fieldType), uint256(FieldType.ENUM));
        assertEq(schema.fields[3].isArray, false);
        assertEq(schema.fields[3].allowedSchemaIds.length, 0);
        assertEq(schema.fields[3].enumValues.length, 3);
        assertEq(schema.fields[3].enumValues[0], genderEnum[0]);
        assertEq(schema.fields[3].enumValues[1], genderEnum[1]);
        assertEq(schema.fields[3].enumValues[2], genderEnum[2]);

        // TODO: This isn't _really_ a SchemaRegistry test - should live elsewhere
        // Write a record using this new schema
        bytes memory data = abi.encode(originatorId, "Alice", "https://example.com/alice.jpg", 1);

        RecordRequest memory recordRequest = RecordRequest({
            // TODO: Fix the naming mismatch here? (schema vs schemaUID?)
            schema: schemaUID,
            data: RecordRequestData({revocable: true, updatable: true, data: data, salt: bytes32(0), value: 0})
        });

        bytes32 expectedRecordUID = _getRecordUID(originatorId, originatorId, recordRequest);
        vm.expectEmit();
        emit Attested({originator: originatorId, registrar: originatorId, uid: expectedRecordUID, schemaUID: schemaUID});

        vm.prank(custody);
        bytes32 recordUID = recordRegistry.register(originatorId, recordRequest);

        // Assert postconditions
        assertEq(recordUID, expectedRecordUID);
        Record memory record = recordRegistry.getRecord(recordUID);
        assertEq(record.uid, expectedRecordUID);
        assertEq(record.schema, schemaUID);
        assertEq(record.time, block.timestamp);
        assertEq(record.revocationTime, 0);
        assertEq(record.originator, originatorId);
        assertEq(record.registrar, originatorId);
        assertEq(record.revocable, true);
        assertEq(record.data, data);

        (uint256 accountId, string memory displayName, string memory photoURI, uint8 gender) =
            abi.decode(record.data, (uint256, string, string, uint8));
        assertEq(accountId, originatorId);
        assertEq(displayName, "Alice");
        assertEq(photoURI, "https://example.com/alice.jpg");
        assertEq(genderEnum[gender], "female");
    }

    function testFuzz_appendFields(address custody, uint8 fieldTypeIndex1, uint8 fieldTypeIndex2) public {
        // Bound inputs that need to be bound
        vm.assume(custody != address(0));
        vm.assume(fieldTypeIndex1 < uint8(type(FieldType).max));
        vm.assume(fieldTypeIndex2 < uint8(type(FieldType).max));

        FieldType fieldType1 = FieldType(fieldTypeIndex1);
        FieldType fieldType2 = FieldType(fieldTypeIndex2);

        // Enums require an enum array, which I don't want write logic to populate
        vm.assume(fieldType1 != FieldType.ENUM && fieldType2 != FieldType.ENUM);

        // Register a Royal account for the custody address.
        _register(custody, "username");

        // Define and register schema
        FieldDefinition[] memory fields = new FieldDefinition[](1);
        fields[0] = FieldDefinition({
            fieldName: "field1",
            fieldType: fieldType1,
            isArray: false,
            allowedSchemaIds: new bytes32[](0),
            enumValues: new string[](0)
        });

        vm.prank(custody);
        bytes32 schemaUID = schemaRegistry.register({
            name: "schema1",
            fields: fields,
            revocable: true,
            updatable: true,
            resolver: ISchemaResolver(address(0)),
            salt: bytes32(0)
        });

        // Append a new field
        FieldDefinition[] memory newFields = new FieldDefinition[](1);
        newFields[0] = FieldDefinition({
            fieldName: "field2",
            fieldType: fieldType2,
            isArray: false,
            allowedSchemaIds: new bytes32[](0),
            enumValues: new string[](0)
        });

        vm.expectEmit();
        emit SchemaUpdated({uid: schemaUID, numAddedFields: 1});

        vm.prank(custody);
        schemaRegistry.appendFields(schemaUID, newFields);

        // Assert postconditions
        Schema memory schema = schemaRegistry.getSchema(schemaUID);
        assertEq(schema.fields.length, 2);

        assertEq(schema.fields[0].fieldName, "field1");
        assertEq(uint256(schema.fields[0].fieldType), uint256(fieldType1));
        assertEq(schema.fields[0].isArray, false);
        assertEq(schema.fields[0].allowedSchemaIds.length, 0);
        assertEq(schema.fields[0].enumValues.length, 0);

        assertEq(schema.fields[1].fieldName, "field2");
        assertEq(uint256(schema.fields[1].fieldType), uint256(fieldType2));
        assertEq(schema.fields[1].isArray, false);
        assertEq(schema.fields[1].allowedSchemaIds.length, 0);
        assertEq(schema.fields[1].enumValues.length, 0);
    }

    function testFuzz_appendEnumValues(address custody, bytes32 enumValue1, bytes32 enumValue2) public {
        // // Bound inputs that need to be bound
        vm.assume(custody != address(0));

        // Register a Royal account for the custody address.
        _register(custody, "username");

        // Define and register schema
        string[] memory enumValues = new string[](1);
        enumValues[0] = string(abi.encodePacked(enumValue1));

        FieldDefinition[] memory fields = new FieldDefinition[](1);
        fields[0] = FieldDefinition({
            fieldName: "field1",
            fieldType: FieldType.ENUM,
            isArray: false,
            allowedSchemaIds: new bytes32[](0),
            enumValues: enumValues
        });

        vm.prank(custody);
        bytes32 schemaUID = schemaRegistry.register({
            name: "schema1",
            fields: fields,
            revocable: true,
            updatable: true,
            resolver: ISchemaResolver(address(0)),
            salt: bytes32(0)
        });

        // Append a new enum value
        string[] memory newEnumValues = new string[](1);
        newEnumValues[0] = string(abi.encodePacked(enumValue2));

        vm.expectEmit();
        emit SchemaFieldUpdated({uid: schemaUID, fieldIndex: 0});

        vm.prank(custody);
        schemaRegistry.appendEnumValues(schemaUID, 0, newEnumValues);

        // Assert postconditions
        Schema memory schema = schemaRegistry.getSchema(schemaUID);
        assertEq(schema.fields[0].enumValues.length, 2);
        assertEq(schema.fields[0].enumValues[0], string(abi.encodePacked(enumValue1)));
        assertEq(schema.fields[0].enumValues[1], string(abi.encodePacked(enumValue2)));
    }

    function testFuzz_appendAllowedSchemaIds(address custody1, address custody2) public {
        // Bound inputs that need to be bound
        vm.assume(custody1 != address(0));
        vm.assume(custody2 != address(0));
        vm.assume(custody1 != custody2);

        // Register a Royal account for the wallet addresses.
        _register(custody1, "username1");
        _register(custody2, "username2");

        // Define and register example schemas
        FieldDefinition[] memory fields = new FieldDefinition[](1);
        fields[0] = FieldDefinition({
            fieldName: "isTrue",
            fieldType: FieldType.BOOL,
            isArray: false,
            allowedSchemaIds: new bytes32[](0),
            enumValues: new string[](0)
        });

        vm.prank(custody1);
        bytes32 schemaUID1 = schemaRegistry.register({
            name: "schema1",
            fields: fields,
            revocable: true,
            updatable: true,
            resolver: ISchemaResolver(address(0)),
            salt: bytes32(0)
        });

        vm.prank(custody2);
        bytes32 schemaUID2 = schemaRegistry.register({
            name: "schema2",
            fields: fields,
            revocable: true,
            updatable: true,
            resolver: ISchemaResolver(address(0)),
            salt: bytes32(0)
        });

        // Define and register actual schema
        bytes32[] memory allowedSchemaIds = new bytes32[](1);
        allowedSchemaIds[0] = schemaUID1;

        fields[0] = FieldDefinition({
            fieldName: "recordId",
            fieldType: FieldType.RECORD_ID,
            isArray: false,
            allowedSchemaIds: allowedSchemaIds,
            enumValues: new string[](0)
        });

        vm.prank(custody1);
        bytes32 schemaUID = schemaRegistry.register({
            name: "schema1",
            fields: fields,
            revocable: true,
            updatable: true,
            resolver: ISchemaResolver(address(0)),
            salt: bytes32(0)
        });

        // Append a new allowed schema ID
        bytes32[] memory newAllowedSchemaIds = new bytes32[](1);
        newAllowedSchemaIds[0] = schemaUID2;

        vm.expectEmit();
        emit SchemaFieldUpdated({uid: schemaUID, fieldIndex: 0});

        vm.prank(custody1);
        schemaRegistry.appendAllowedSchemaIds(schemaUID, 0, newAllowedSchemaIds);

        // Assert postconditions
        Schema memory schema = schemaRegistry.getSchema(schemaUID);
        assertEq(schema.fields[0].allowedSchemaIds.length, 2);
        assertEq(schema.fields[0].allowedSchemaIds[0], schemaUID1);
        assertEq(schema.fields[0].allowedSchemaIds[1], schemaUID2);
    }

    // =============================================================
    //                        ASSERTION HELPERS
    // =============================================================

    // function _assertRegisterPreconditions(
    //     uint256 id,
    //     uint256 originatorId,
    //     bytes32 contentHash,
    //     address nftContract,
    //     uint256 nftTokenId
    // ) internal {
    //     assertEq(provenanceRegistry.idCounter(), 0);

    //     assertEq(provenanceRegistry.provenanceClaimIdOfNftToken(nftContract, nftTokenId), 0);
    //     assertEq(provenanceRegistry.provenanceClaimIdOfOriginatorAndHash(originatorId, contentHash), 0);

    //     vm.expectRevert(ProvenanceClaimNotFound.selector);
    //     provenanceRegistry.provenanceClaim(id);
    // }

    // function _assertRegisterPostconditions(
    //     uint256 id,
    //     uint256 originatorId,
    //     uint256 registrarId,
    //     bytes32 contentHash,
    //     address nftContract,
    //     uint256 nftTokenId
    // ) internal view {
    //     assertEq(provenanceRegistry.idCounter(), id);
    //     assertEq(provenanceRegistry.provenanceClaimIdOfOriginatorAndHash(originatorId, contentHash), id);

    //     if (nftContract != address(0)) {
    //         assertEq(provenanceRegistry.provenanceClaimIdOfNftToken(nftContract, nftTokenId), id);
    //     } else {
    //         assertEq(provenanceRegistry.provenanceClaimIdOfNftToken(nftContract, nftTokenId), 0);
    //     }

    //     IProvenanceRegistry.ProvenanceClaim memory provenanceClaim = provenanceRegistry.provenanceClaim(id);
    //     assertEq(provenanceClaim.originatorId, originatorId);
    //     assertEq(provenanceClaim.registrarId, registrarId);
    //     assertEq(provenanceClaim.contentHash, contentHash);
    //     assertEq(provenanceClaim.nftContract, nftContract);
    //     assertEq(provenanceClaim.nftTokenId, nftTokenId);

    //     // NOTE: Where appropriate, blockNumber is fuzzed and set via vm.roll().
    //     //       Might be cleaner to pass in blockNumber as a param here, but this is sufficient for now.
    //     assertEq(provenanceClaim.blockNumber, block.number);
    // }

    function _getSchemaUID(uint256 originatorId, string memory name, bytes32 salt) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(originatorId, name, salt));
    }

    function _getRecordUID(uint256 originator, uint256 registrar, RecordRequest memory recordRequest)
        internal
        pure
        returns (bytes32 uid)
    {
        return keccak256(abi.encodePacked(originator, registrar, recordRequest.schema, recordRequest.data.data));
    }
}
