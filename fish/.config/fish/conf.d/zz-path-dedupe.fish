# Collapse duplicate path entries inherited from nested shells (fish_add_path
# only dedupes its own additions, not entries inherited from the parent env).
# Named zz- so it sorts after the other conf.d hooks: lerd.fish prepends its bin
# dir with `set -gx PATH` on every shell, which re-adds an inherited entry.
for var in PATH CDPATH MANPATH
    set -q $var; or continue
    set -l seen
    for entry in $$var
        test -n "$entry"; or continue
        contains -- $entry $seen; and continue
        set -a seen $entry
    end
    set -gx $var $seen
end
