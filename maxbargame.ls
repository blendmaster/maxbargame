width = 500; height = 500

vertices = d3.range 9 .map -> new Vertex
edges = (.map ([s, t, b]) -> new Edge vertices[s], vertices[t], b) [] =
  * 0 1 10
  * 1 2 7
  * 2 3 15
  * 3 4 5
  * 3 6 10
  * 6 5 9
  * 1 6 20
  * 1 8 10
  * 8 7 6
  * 6 7 5

topology = {vertices, edges}

players = (.map ([s, t]) -> new Player vertices[s], vertices[t]) [] =
  * 0 6
  * 8 3
  * 5 2

path-idx = (.map (.map (edges.))) [] =
  * 0 1 2 4
  * 8 9 4
  * 5 4 2

player-color = d3.scale.ordinal!
  .range colorbrewer.Dark2.8

paths = {}
for p, i in players
  paths[p] = path-idx[i]

game = maxbargame do
  topology
  players
  allocate topology, paths

document.get-element-by-id \scale
  stroke-scale = parse-float ..value
  ..add-event-listener \input !->
    stroke-scale := parse-float @value
    draw!

force = d3.layout.force!
  .size [width, height]
  .nodes vertices
  .links edges
  .link-distance 100
  .charge -500

idx = 0
state = game[idx]
users = {}
let
  for player, strategy of state.strategies
    for edge in strategy.path
      users[][edge]push player

document.get-element-by-id \play-pause
  .add-event-listener \click !->
    idx++
    return unless game[idx]?
    state := game[idx]
    users := {}
    for player, strategy of state.strategies
      for edge in strategy.path
        users[][edge]push player
    force.stop!
    draw 2000ms

alloc-line = (state, users, player, edge) -->
  strategy = state.strategies[player]

  {x: x1, y: y1} = edge.0; {x: x2, y: y2} = edge.1;

  # adjust to angle of path, so that all allocations on the edge
  # are shown
  offset-start = 0
  for u in users[edge]
    break if u is "#player"
    offset-start += state.strategies[u]bandwidth

  # since stroke width is from the center, increase offset by half
  # of our bandwidth
  b = strategy.bandwidth
  offset-mid = offset-start + b / 2
  offset-end = offset-start + b

  # offset-start is from top edge of edge's pipe, so y-offset is
  # actually negative for above the center
  offset = offset-mid - edge.bandwidth / 2

  # offset is a y-offset if our path is horizontal, so rotate
  # according to edge orientation
  offset *= stroke-scale
  angle = Math.atan2 y1 - y2, x2 - x1
  x-offset = offset * Math.sin angle
  y-offset = offset * Math.cos angle

  x1 += x-offset
  x2 += x-offset
  y1 += y-offset
  y2 += y-offset

  {
    angle, offset-start, offset-end,
    offset, x1, x2, y1, y2, bottleneck: edge is strategy.bottleneck
  }

var selected

svg = d3.select \#topology
  ..on \click !->
    if d3.event.target is this
      if d3.event.ctrl-key and selected?
        v = new Vertex
        [x, y] = d3.mouse this
        v.x = x; v.y = y
        vertices.push v
        edges.push new Edge v, selected, 10
        force.start!
      else
        selected := void
        draw!

force.on \tick !-> draw!

transition = (sel, duration) ->
  if duration > 0
    sel.transition!duration duration
  else
    sel

fade-out = (it, duration) ->
  it.exit!
    .remove!
    .attr \class null # keep out of subsequent selections
    .transition!duration duration .style \opacity 0.01 .remove!

identity = -> it

drag-edge = d3.behavior.drag!
  .on \dragstart !->
    force.stop!
  .on \drag !(edge) ->
    edge.bandwidth -= d3.event.dy / stroke-scale
    edge.bandwidth = Math.max 1, edge.bandwidth
    paths = {}
    for p, strategy of state.strategies
      paths[p] = strategy.path
    state := new State allocate topology, paths
    draw!
  .on \dragend !->
    #draw 1000ms
    force.resume!

# draw stuff
draw = !(duration) ->
  d3.select \#edges .select-all \.edge .data edges, identity
    ..exit!remove!
    ..enter!append \line .attr \class \edge
    transition .. .attr do
      x1: (.0.x)
      y1: (.0.y)
      x2: (.1.x)
      y2: (.1.y)
      \stroke-width : (.bandwidth) >> (* stroke-scale)
  d3.select \#edge-handles .select-all \.edge-handle .data edges, identity
    ..exit!remove!
    ..enter!append \line .attr \class \edge-handle
      ..call drag-edge
    transition .. .attr do
      x1: (.0.x)
      y1: (.0.y)
      x2: (.1.x)
      y2: (.1.y)
      \stroke-width : (.bandwidth) >> (* stroke-scale)
  d3.select \#vertices .select-all \.vertex .data vertices, identity
    ..exit!remove!
    ..enter!append \circle
      .attr \class \vertex
    ..classed \selected (is selected)
    transition .. .attr do
      cx: (.x)
      cy: (.y)
      r: -> 0.5 * stroke-scale * d3.max it.edges, (.bandwidth)
  d3.select \#handles .select-all \.handle .data vertices, identity
    ..exit!remove!
    ..enter!append \circle
      .attr \class \handle
      .call force.drag
      .on \click !(vertex) ->
        unless d3.event.default-prevented
          if d3.event.ctrl-key and selected?
            unless vertex.srobhgien[selected]?
              edges.push new Edge vertex, selected, 10
              force.start!
          else if d3.event.shift-key
            if not vertex.player and not vertex.edges.some((e) -> users[e]?)
              if connected topology, vertex # if still connected without vertex
                # remove
                vertices.splice vertices.index-of(vertex), 1
                for vertex.edges
                  edges.splice edges.index-of(..), 1

                for vertex.edges
                  if vertex is ..0
                    ..1.edges.splice ..1.edges.index-of(..), 1
                    delete ..1.neighbors[..]
                    delete ..1.srobhgien[..0]
                  else
                    ..0.edges.splice ..0.edges.index-of(..), 0
                    delete ..0.neighbors[..]
                    delete ..0.srobhgien[..1]

                force.start!
          else
            selected := vertex
    transition .. .attr do
      cx: (.x)
      cy: (.y)
      r: -> 0.5 * stroke-scale * d3.max it.edges, (.bandwidth)
  d3.select \#wedges .select-all \.wedges .data vertices, identity
    fade-out .., duration
    ..enter!append \g
      ..attr \class \wedges
    w = ..select-all \.wedge .data do
      ->
        p = []
        for edge in it.edges
          for player in users[edge] || 0
            p.push {player, edge}
        return p
      ->
        "#{it.player}#{it.edge}"
    w
      ..exit!
        .attr \class null
        .transition!duration duration .style \opacity \0.01 .remove!
      ..enter!append \path
        ..attr \class \wedge
        ..style \opacity 0.01
        ..style \fill (.player) >> player-color
      transition .., duration
        .attr \d ({player, edge}, i, vertex-id) ->
          vertex = vertices[vertex-id]

          cx = vertex.x
          cy = vertex.y
          r = 0.5 * stroke-scale * d3.max vertex.edges, (.bandwidth)
          line = alloc-line state, users, player, edge

          {angle, offset-start, offset-end} = line
          offset-start -= edge.bandwidth / 2
          offset-end -= edge.bandwidth / 2
          offset-start *= stroke-scale; offset-end *= stroke-scale

          if vertex is edge.0
            x2 = edge.1.x
            y2 = edge.1.y
            sign = d-sign = 1
          else
            x2 = edge.0.x
            y2 = edge.0.y
            sign = d-sign = -1

          osx = offset-start * Math.sin angle
          osy = offset-start * Math.cos angle
          oex = offset-end * Math.sin angle
          oey = offset-end * Math.cos angle

          # intersect offset-start line with circle
          dx = x2 - cx
          dy = y2 - cy
          dr = Math.sqrt dx**2 + dy**2
          D = osx * (dy + osy) - (dx + osx) * osy
          # rounding errors cause it to be negative sometimes
          t = r**2 * dr**2 - D**2
          t = 0 if t < 0

          term = Math.sqrt(t)

          sgn = -> if it < 0 then -1 else 1

          sign *= if angle > 0 then -1 else 1

          isx = (D * dy + sign * sgn(dy) * dx * term) / dr**2
          isy = (-D * dx + sign * Math.abs(dy) * term) / dr**2

          # offset-end line
          D = oex * (dy + oey) - (dx + oex) * oey
          # rounding errors cause it to be negative sometimes
          t = r**2 * dr**2 - D**2
          t = 0 if t < 0

          term = Math.sqrt(t)
          iex = (D * dy + sign * sgn(dy) * dx * term) / dr**2
          iey = (-D * dx + sign * Math.abs(dy) * term) / dr**2

          ddx = iex - isx
          ddy = iey - isy

          # center to offset-end, then arc to offset-start, close
          "
          M #cx #cy \
          l #isx #isy \
          a #r #r 0 0 #{if d-sign > 0 then 1 else 0} #ddx #ddy \
          Z
          "
        .style \opacity 1
  d3.select \#players .select-all \.player .data players, identity
    ..exit!remove!
    ..enter!append \g
      ..attr \id -> "player-#it"
      ..attr \class \player
      ..style \stroke player-color
    l = ..select-all \.segment .data do
      (player) ->
        state.strategies[player]path.map ->
          edge: it
          line: alloc-line(state, users, player, it)
      (segment, i) ->
        "#{segment.edge}#i"
    l
      ..exit!
        .attr \class null
        .transition!duration duration .style \opacity \0.01 .remove!
      ..enter!append \line .attr \class \segment
        ..style \stroke-opacity 0.01
      transition .., duration
        .attr do
          x1: (.line.x1)
          y1: (.line.y1)
          x2: (.line.x2)
          y2: (.line.y2)
          \stroke-width : (d, i, j) ->
            state.strategies[players[j]]bandwidth * stroke-scale
        .style \stroke-opacity 1
      ..classed \bottleneck (.line.bottleneck)

force.start!
