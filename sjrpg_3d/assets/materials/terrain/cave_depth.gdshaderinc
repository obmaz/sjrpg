// 암반과 실제 보행 바닥이 같은 입구 좌표의 깊이 감쇠를 공유한다.
// 첫 1m의 측벽/천장은 남기고 구릉 안쪽만 단계적으로 어둡게 한다.
float cave_depth_visibility(vec3 site) {
 float centre = -0.12 - 0.14*smoothstep(2.5,6.5,-site.z);
 float inside = (1.0-smoothstep(1.8,2.25,abs(site.x-centre))) * (1.0-smoothstep(3.0,3.6,site.y));
 // 뒤쪽 구릉 밖의 먼 필드까지 어두운 띠가 이어지지 않게 범위를 닫는다.
 inside *= 1.0-smoothstep(6.7,9.8,-site.z);
 float near_shade = 0.10*smoothstep(0.15,1.0,-site.z);
 float deep_shade = 0.86*smoothstep(1.2,5.6,-site.z);
 return 1.0-inside*min(0.96,near_shade+deep_shade);
}
