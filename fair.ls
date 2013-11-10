height = 300; width = 500
sections =
  0
  width / 5
  2 * width / 5
  3 * width / 5
  4 * width / 5
  5 * width / 5
handle-height = 10

body = d3.select document.body

lock = document.get-element-by-id \lock
  ..checked = true

svg = d3.select \#svg 
  ..attr do
    {width, height, viewBox: "0 0 #width #height", preserveAspectRatio: \none}
  paths = ..append \g .attr \id \paths
  wants = ..append \g .attr \id \wants
  limits = ..append \g .attr \id \limits
  handles = ..append \g .attr \id \handles
    handle-top = ..append \rect
      .attr do
        id: \handle-top
        x: sections.2
        width: sections.1
        height: handle-height
    handle-bot = ..append \rect
      .attr do
        id: \handle-bot
        x: sections.2
        width: sections.1
        height: handle-height

class Player
  (@id, @wanted, @limited) ->
    @needed = Math.min @wanted, @limited
  to-string: -> @id

players = (.map ([w, l], i) -> new Player i, w, l) [] =
  * 50 50
  * 60 60
  * 70 30
  * 30 30

bandwidth = 100
by-needed = comparator (.needed)

var allocs, stack-allocs
reallocate = !->
  sorted = players.slice!sort by-needed
  allocs := max-min-fair sorted, bandwidth

  offset = 0
  stack-allocs := for p in players
    o = offset
    offset += allocs[p]
    o

reallocate!

delay-idx = {}
for p, i in players
  delay-idx[p] = i

drag = d3.behavior.drag!
  .on \dragstart !->
    body.classed \dragging true
  .on \drag !->
    bandwidth := Math.max 1,
      2 * Math.abs height/2 - (d3.event.y)
    reallocate!
    draw-schematic!
  .on \dragend !->
    body.classed \dragging false
    draw-schematic 1000ms
handle-top.call drag
handle-bot.call drag

drag-wanted = d3.behavior.drag!
  .on \dragstart !->
    body.classed \dragging true
  .on \drag !(player) ->
    player.wanted += (d3.event.dy)
    player.wanted = Math.max 1, player.wanted
    if lock.checked
      player.limited = player.wanted
    player.needed = Math.min player.wanted, player.limited

    for p, i in players
      delay-idx[p] =
        if p is player then 0
        else if p.id > player.id then i
        else i + 1

    reallocate!
    draw-schematic!
  .on \dragend !->
    body.classed \dragging false
    reallocate!
    draw-schematic!

drag-limited = d3.behavior.drag!
  .on \dragstart !->
    body.classed \dragging true
  .on \drag !(player) ->
    player.limited += d3.event.dy
    player.limited = Math.max 1, player.limited
    if lock.checked
      player.wanted = player.limited
    player.needed = Math.min player.wanted, player.limited
    for p, i in players
      delay-idx[p] =
        if p is player then 0
        else if p.id > player.id then i
        else i + 1

    reallocate!
    draw-schematic!
  .on \dragend !->
    body.classed \dragging false
    reallocate!
    draw-schematic!

curve = sections.1 / 3

attr = (sel, duration, delay, attrs, val) ->
  if duration > 0
    if val?
      sel.transition duration .delay delay .attr attrs, val
    else
      sel.transition duration .delay delay .attr attrs
  else
    if val?
      sel.attr attrs, val
    else
      sel.attr attrs

draw-schematic = !(duration ? 0) ->
  offset = 0
  stack-wanted = for p in players
    o = offset
    offset += p.wanted
    o

  offset = 0
  stack-limited = for p in players
    o = offset
    offset += p.limited
    o

  start-pipe = height / 2 - bandwidth / 2
  end-pipe = start-pipe + bandwidth

  delay = (d, i) -> 1000 * delay-idx[d] / players.length

  attr handle-top, duration, 0, \y (start-pipe) - handle-height
  attr handle-bot, duration, 0, \y (end-pipe)
  wants.select-all \.want .data players
    ..exit!remove!
    ..enter!append \rect
      .attr \class -> "want player-#it"
      .call drag-wanted
      .attr x: 0, width: sections.1 - sections.0
    attr .., duration, delay,
      x: 0
      y: (p, i) -> Math.max stack-limited[i], stack-wanted[i]
      height: (.wanted)
  limits.select-all \.limit .data players
    ..exit!remove!
    ..enter!append \rect
      .attr \class -> "limit player-#it"
      .attr x: sections.4, width: sections.4 - sections.3
      .call drag-limited
    attr .., duration, delay,
      y: (p, i) -> Math.max stack-limited[i], stack-wanted[i]
      height: (.limited)
  paths.select-all \.alloc .data players
    ..exit!remove!
    ..enter!append \path .attr do
      class: -> "alloc player-#it"
    attr .., duration, delay,
      d: (p, i) ->
        thickness = Math.min p.limited, p.wanted, allocs[p]
        start = Math.max stack-limited[i], stack-wanted[i]
        end-w = start + thickness
        end-l = start + thickness
        a = start-pipe + stack-allocs[i]
        end-a = a + thickness
        "
        M #{sections.0} #start
        L #{sections.1} #start
        C #{sections.1 + curve} #start #{sections.2 - curve} #a #{sections.2} #a
        L #{sections.3} #a
        C #{sections.3 + curve} #a #{sections.4 - curve} #start #{sections.4} #start
        L #{sections.5} #start
        L #{sections.5} #end-l
        L #{sections.4} #end-l
        C #{sections.4 - curve} #end-l #{sections.3 + curve} #end-a #{sections.3} #end-a
        L #{sections.2} #end-a
        C #{sections.2 - curve} #end-a #{sections.1 + curve} #end-w #{sections.1} #end-w
        L #{sections.0} #end-w
        Z
        "

draw-schematic!

function comparator view
  (a, b) -> view(a) - view(b)

function max-min-fair players, bandwidth
  allocs = {}
  i = players.length
  for player in players
    fair = bandwidth / i--
    alloc = if player.needed > fair then fair else player.needed
    bandwidth -= alloc
    allocs[player] = alloc
  return allocs

