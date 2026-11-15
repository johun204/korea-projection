# RTL8812BU 드라이버 빌드(K8 GL3, 커널 3.18.24-tcc)

차 진단 USB(`dongle-diag/`)로 얻은 커널 설정·이미지·순정 모듈을 기준으로, 그 커널에 맞는 `88x2bu.ko`를 만든다.

- 커널 소스: AOSP `kernel/common` `deprecated/android-3.18`의 2016-01 지점(`android-base.txt`) + upstream `v3.18.24`를 병합
  (`merge.sh`, `resolve.sh`). 순정 모듈 DWARF에서 확인한 제조사 차이 4곳을 맞춤(vmacache_seqnum u64, file_operations.iterate_avn,
  linux_mib 항목 1개). 설정은 `car-kernel.config`(차의 /proc/config.gz).
- 드라이버: morrownr/88x2bu-20210702, `CONFIG_POWER_SAVING=n CONFIG_RTW_LOG_LEVEL=3`, `-fno-pic`, gcc 4.7(차 커널과 같은 판).
- 빌드: Docker(colima, `Dockerfile`)에서 `run.sh prep2.sh`, `run.sh drv.sh ...`. 같은 입력으로 두 번 빌드해 결과가 같음을 확인.

## 검증(차에 올리기 전)

| 항목 | 결과 |
|---|---|
| vermagic | `3.18.24-tcc SMP preempt mod_unload ARMv7 p2v8` 차와 같음 |
| 가져다 쓰는 커널 심볼 196개 | 모두 차 커널이 내보냄(kallsyms) |
| 순정 모듈(bcmdhd·vpu·dup_ttyd)과 겹치는 구조체 895개 | 배치가 모두 같음(`verify_ko.py`) |
| 드라이버가 부르는 커널 함수 171개 | 168개가 차 커널 이미지와 바이트까지 같음(`match_imports.py`). 나머지 3개: kmalloc·kfree(SLAB_FREELIST_HARDENED 내부), register_netdevice(경고 줄 번호) — 부르는 방식과 무관 |

모듈 서명·MODVERSIONS가 꺼진 커널이라, 이 검증이 커널의 버전 검사를 대신한다.
