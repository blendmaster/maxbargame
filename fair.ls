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
mode = document.get-element-by-id \mode

svg = d3.select \#svg
  ..attr do
    {width, height, viewBox: "0 0 #width #height", preserveAspectRatio: \none}
  pipe = ..append \rect .attr {width: sections.1, x: sections.2, height: bandwidth}
    .attr \id \pipe
  paths = ..append \g .attr \id \paths
  wants = ..append \g .attr \id \wants
  limits = ..append \g .attr \id \limits
  make-new = ..append \rect .attr \id \make-new
    .attr {width, x: 0, height: 0}
  pending-player = ..append \path .attr \id \pending-player

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

id = 0
class Player
  (@wanted, @limited) ->
    @id = id++
    @color = @id % 8
    @needed = Math.min @wanted, @limited
    @space = Math.max @wanted, @limited
  to-string: -> @id

players = [new Player 50, 50]

bandwidth = 100

by-needed = comparator (.needed)
by-space = comparator (.space)

allocs = {}
var stack-allocs
reallocate = !->
  allocs := {}
  stack-allocs := {}
  switch mode.value
  case \first
    remaining = bandwidth
    for p in players
      allocs[p] = alloc = Math.min remaining, p.needed
      remaining -= alloc
  case \equal
    fair = bandwidth / players.length
    for p in players
      allocs[p] = fair
  case \fair
    sorted = players.slice!sort by-needed
    allocs := max-min-fair sorted, bandwidth

  offset = 0
  for p in players
    stack-allocs[p] = offset
    offset += allocs[p]

reallocate!

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
    player.wanted = Math.max 0, player.wanted
    if lock.checked
      player.limited = player.wanted
    player.needed = Math.min player.wanted, player.limited
    player.space = Math.max player.wanted, player.limited

    reallocate!
    draw-schematic!
  .on \dragend !(player) ->
    if player.needed < 5
      players.splice players.index-of(player), 1
      duration = 1500ms
    else
      duration = 0
    body.classed \dragging false
    reallocate!
    draw-schematic duration

mode-change = !->
  reallocate!
  draw-schematic 1500ms
mode.add-event-listener \change mode-change
mode.add-event-listener \keyup mode-change

drag-limited = d3.behavior.drag!
  .on \dragstart !->
    body.classed \dragging true
  .on \drag !(player) ->
    player.limited += d3.event.dy
    player.limited = Math.max 0, player.limited
    if lock.checked
      player.wanted = player.limited
    player.needed = Math.min player.wanted, player.limited
    player.space = Math.max player.wanted, player.limited
    reallocate!
    draw-schematic!
  .on \dragend !->
    if player.needed < 5
      players.splice players.index-of(player), 1
      duration = 1500ms
    else
      duration = 0
    body.classed \dragging false
    reallocate!
    draw-schematic duration

new-needed = 0
var new-player

make-new.call do
  d3.behavior.drag!
    .on \drag !->
      new-needed += d3.event.dy
      new-needed := Math.max 0, new-needed
      draw-schematic!
    .on \dragend !->
      if new-needed > 5
        new-player := new Player new-needed, new-needed
        players.push new-player
      new-needed := 0
      reallocate!
      draw-schematic 1000ms

curve = sections.1 / 3

attr = (sel, duration, attrs, val) ->
  if duration > 0
    if val?
      sel.transition!duration duration .attr attrs, val
    else
      sel.transition!duration duration .attr attrs
  else
    if val?
      sel.attr attrs, val
    else
      sel.attr attrs

draw-schematic = !(duration ? 0) ->
  remaining = height
  i = players.length + 1 # extra space
  layout = {}
  for p in players.slice!sort by-space .reverse!
    equal = remaining / i--
    layout[p] = lay = if p.space > equal then p.space else equal
    remaining -= lay

  offset = {}
  used = 0
  for p in players
    offset[p] = used + layout[p]/2 - p.space/2
    used += layout[p]

  make-new.attr height: remaining, y: used
  start = used + remaining/2 - new-needed/2
  end = start + new-needed

  start-pipe = height / 2 - bandwidth / 2
  end-pipe = start-pipe + bandwidth

  attr handle-top, duration, \y (start-pipe) - handle-height
  attr handle-bot, duration, \y (end-pipe)
  attr pipe, duration, y: start-pipe, height: bandwidth
  wants.select-all \.want .data players, (.id)
    ..exit!transition 1000ms .style \opacity 0 .remove!
    ..enter!append \rect
      .attr \class -> "want q#{it.color}-8"
      .call drag-wanted
      .attr x: 0, width: sections.1 - sections.0, height: 0
      .attr \y -> if it is new-player then start
    attr .., duration,
      x: 0
      y: (offset.)
      height: (.wanted)
  limits.select-all \.limit .data players, (.id)
    ..exit!transition 1000ms .style \opacity 0 .remove!
    ..enter!append \rect
      .attr \class -> "limit q#{it.color}-8"
      .attr x: sections.4, width: sections.4 - sections.3, height: 0
      .attr \y -> if it is new-player then start
      .call drag-limited
    attr .., duration,
      y: (offset.)
      height: (.limited)
  paths.select-all \.alloc .data players, (.id)
    ..exit!transition 1000ms .style \opacity 0 .remove!
    ..enter!append \path .attr do
      class: -> "alloc q#{it.color}-8"
      d: -> if it is new-player then pending-player.attr \d else null
    attr .., duration,
      d: (p) ->
        thickness = Math.min p.limited, p.wanted, allocs[p]
        start = offset[p]
        end-w = start + thickness
        end-l = start + thickness
        a = start-pipe + stack-allocs[p]
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
  pending-player.attr \d,
    "
    M #{sections.0} #start
    L #{sections.1} #start
    C #{sections.1 + curve} #start #{sections.2 - curve} #start #{sections.2} #start
    L #{sections.3} #start
    C #{sections.3 + curve} #start #{sections.4 - curve} #start #{sections.4} #start
    L #{sections.5} #start
    L #{sections.5} #end
    L #{sections.4} #end
    C #{sections.4 - curve} #end #{sections.3 + curve} #end #{sections.3} #end
    L #{sections.2} #end
    C #{sections.2 - curve} #end #{sections.1 + curve} #end #{sections.1} #end
    L #{sections.0} #end
    Z
    "
  pending-player.attr \class "q#{id % 8}-8"

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

