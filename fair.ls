height = 400; width = 500
sections =
  0
  width / 5
  2 * width / 5
  3 * width / 5
  4 * width / 5
  5 * width / 5
handle-height = 10

body = d3.select document.body

svg = d3.select \#svg .attr {width, height}
  wants = ..append \g .attr \id \wants
  paths = ..append \g .attr \id \paths
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
  * 5 5
  * 6 6
  * 7 3
  * 3 3

bandwidth = 10
by-needed = comparator (.needed)

var allocs, stack-allocs
reallocate = !->
  allocs := max-min-fair players, bandwidth

  offset = 0
  stack-allocs := for p in players
    o = offset
    offset += allocs[p]
    o

reallocate!

var y-scale, total-wanted, total-limited, scale-height
var wanted-padding, limited-padding, stack-wanted, stack-limited
rescale = !->
  total-wanted := d3.sum players, (.wanted)
  total-limited := d3.sum players, (.limited)
  scale-height := Math.max(total-limited, total-wanted, bandwidth) + 1
  wanted-padding := (scale-height - total-wanted) / (players.length - 1)
  limited-padding := (scale-height - total-limited) / (players.length - 1)

  y-scale := d3.scale.linear!
    .domain [0 scale-height]
    .range [0 height]

  offset = 0
  stack-wanted := for p in players
    o = offset
    offset += p.wanted + wanted-padding
    o

  offset = 0
  stack-limited := for p in players
    o = offset
    offset += p.limited + wanted-padding
    o

rescale!

drag = d3.behavior.drag!
  .on \dragstart !->
    body.classed \dragging true
  .on \drag !->
    bandwidth := Math.max 1,
      2 * Math.abs scale-height/2 - y-scale.invert(d3.event.y)
    reallocate!
    draw-schematic!
  .on \dragend !->
    body.classed \dragging false
    rescale!
    draw-schematic!
handle-top.call drag
handle-bot.call drag

curve = sections.1 / 3

draw-schematic = !->
  start-pipe = scale-height / 2 - bandwidth / 2
  end-pipe = start-pipe + bandwidth

  handle-top.attr \y y-scale(start-pipe) - handle-height
  handle-bot.attr \y y-scale(end-pipe)
  wants.select-all \.want .data players
    ..exit!remove!
    ..enter!append \rect .attr do
      class: -> "want player-#it"
    ..attr do
      x: 0
      y: (p, i) -> y-scale Math.max stack-limited[i], stack-wanted[i]
      width: sections.1 - sections.0
      height: y-scale << (.wanted)
  limits.select-all \.limit .data players
    ..exit!remove!
    ..enter!append \rect .attr do
      class: -> "limit player-#it"
    ..attr do
      x: sections.4
      y: (p, i) -> y-scale Math.max stack-limited[i], stack-wanted[i]
      width: sections.4 - sections.3
      height: y-scale << (.limited)
  paths.select-all \.alloc .data players
    ..exit!remove!
    ..enter!append \path .attr do
      class: -> "alloc player-#it"
    ..attr do
      d: (p, i) ->
        start = y-scale Math.max stack-limited[i], stack-wanted[i]
        end-w = start + y-scale p.limited
        end-l = start + y-scale allocs[i]
        a = y-scale start-pipe + stack-allocs[i]
        end-a = a + y-scale allocs[i]
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
  for player in players.slice!sort by-needed
    fair = bandwidth / i--
    alloc = if player.needed > fair then fair else player.needed
    bandwidth -= alloc
    allocs[player] = alloc
  return allocs

