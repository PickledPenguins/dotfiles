# lib/cache.sh: TTL bookkeeping by key, the one place every cached value
# in the toolkit (git state, collectors) decides whether it is stale.

load test_helper

setup() {
    source "$DOTFILES_ROOT/lib/cache.sh"
}

@test "cache_stale: a never-touched key is stale" {
    run cache_stale never_touched_key 5
    [ "$status" -eq 0 ]
}

@test "cache_stale: fresh immediately after cache_touch" {
    cache_touch mykey
    run cache_stale mykey 5
    [ "$status" -eq 1 ]
}

@test "cache_stale: stale once TTL has elapsed" {
    cache_touch mykey
    sleep 1.2   # TTL below is 1s — real elapsed time, not $SECONDS: cache.sh
                # prefers EPOCHSECONDS on bash 5+, which manipulating
                # $SECONDS directly would not have affected.
    run cache_stale mykey 1
    [ "$status" -eq 0 ]
}

@test "cache_age: -1 for a never-touched key, 0 immediately after touch" {
    [ "$(cache_age untouched)" = "-1" ]
    cache_touch justnow
    [ "$(cache_age justnow)" = "0" ]
}

@test "cache_stale: SECONDS going backwards ($SECONDS=0 idiom) is treated as stale, not fresh forever" {
    _CACHE_USE_EPOCH=0   # force the $SECONDS fallback path deliberately
    SECONDS=500
    cache_touch k
    SECONDS=0             # simulates an unrelated `SECONDS=0; time_something` elsewhere
    run cache_stale k 5
    [ "$status" -eq 0 ]   # must be STALE, not incorrectly fresh
}
