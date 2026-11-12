import assert from 'node:assert/strict';
import {assertImportedMerchantAsset, assertWallTorchHeights} from './diagnostic_contracts.mjs';

const asset = 'res://assets/art/native_residents/merchant.glb';
assertImportedMerchantAsset({asset, scene_paths: [asset]}, 'direct legacy model');
assertImportedMerchantAsset({asset, scene_paths: ['res://assets/models/residents/merchant/visual.tscn']}, 'scene-wrapped model');
assert.throws(() => assertImportedMerchantAsset({asset: 'unrelated.glb', scene_paths: [asset]}, 'wrong source'));
assert.throws(() => assertImportedMerchantAsset({asset, scene_paths: ['res://unrelated.tscn']}, 'wrong instance'));
const floor_heights = [0, .65, 1.35, 2.1, 2.1, 1.35, .65, 0, .65, 1.35];
const heights = floor_heights.map(y => y + 1.55);
assertWallTorchHeights({heights, floor_heights});
assert.throws(() => assertWallTorchHeights({heights: Array(10).fill(1.55), floor_heights}));
assert.throws(() => assertWallTorchHeights({heights: heights.map((y, i) => i ? y : NaN), floor_heights}));
assert.throws(() => assertWallTorchHeights({heights, floor_heights: []}));
console.log('DIAGNOSTIC_CONTRACTS_PASS: GLB 씬과 경사진 동굴의 실제 검사 계약');
