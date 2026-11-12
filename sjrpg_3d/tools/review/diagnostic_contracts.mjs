import assert from 'node:assert/strict';

const MERCHANT_GLB = 'res://assets/models/residents/merchant/model.glb';
const MERCHANT_SCENE = 'res://assets/models/residents/merchant/visual.tscn';

export function assertImportedMerchantAsset(model, label) {
    assert.equal(model.asset, MERCHANT_GLB, label + ' uses the licensed source GLB');
    // Godot의 상속 씬 인스턴스는 scene_file_path에 바깥 .tscn만 남길 수 있다.
    assert(model.scene_paths?.some(p => p === MERCHANT_SCENE || p === MERCHANT_GLB), label + ' instantiates its model scene');
}

export function assertWallTorchHeights(torches) {
    assert.equal(torches.heights.length, 10);
    assert.equal(torches.floor_heights.length, torches.heights.length);
    for (let index = 0; index < torches.heights.length; index++) {
        const height = torches.heights[index], floor = torches.floor_heights[index];
        assert(Number.isFinite(height) && Number.isFinite(floor));
        assert(Math.abs(height - floor - 1.55) < .001, 'torch mounting height follows its own cave floor');
    }
}
