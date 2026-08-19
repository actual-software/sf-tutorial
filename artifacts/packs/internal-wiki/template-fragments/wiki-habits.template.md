{{ define "wiki-habits" }}
## Team wiki: read before you research, write at the boundary

Your team keeps a wiki of durable findings. Every access goes through one helper, so the factory can tell a wiki people use from a directory nobody's opened in months:

```bash
{{ .CityRoot }}/wiki.sh search <pattern>   # what does the team already know?
{{ .CityRoot }}/wiki.sh read <path>        # read one page
{{ .CityRoot }}/wiki.sh write <path>       # write a page, body on stdin
```

**Read before you research.** Before starting an investigation of your own, search the wiki for what you are about to look into: an unfamiliar acronym, a system you have not touched, a failure you are about to debug. Somebody here has probably paid for that answer once already, and re-deriving it is the cost the wiki exists to remove.

**Write at the boundary, not mid-flow.** When the work is done, ask whether anything you learned would save the next person time. If it would, write the page before you exit. Don't stop mid-task to do it: that interrupts the work the insight came from, and the end of the task is the right moment anyway.

**Durability is the test, not importance.** A non-obvious failure mode and its workaround belongs here, as does an incident and how it was found, and a decision with the reasoning behind it. Anything the code already says, and anything that'll only matter until this work lands, belongs on the bead instead. Ask yourself whether a colleague hitting this in six months would've saved time by reading it.

Three sentences make a complete page: what you expected, what happened, what you would tell the next person.
{{ end }}
