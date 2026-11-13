// 검수 도구가 배치·상태 변경을 명시적으로 요청하는 공용 URL 진입점이다.
export function inspectionUrl(value, base) {
    const url = new URL(value, base);
    url.searchParams.set('inspection', '1');
    return url;
}
