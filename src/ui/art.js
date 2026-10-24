function artClass(item) {
    return Number.isInteger(item?.artIndex) ? `art-icon art-${item.artIndex}` : '';
}

function itemArt(item, className = '') {
    return `<span class="${className} ${artClass(item)}" aria-hidden="true">${item.icon || '✦'}</span>`;
}

export { artClass, itemArt };
