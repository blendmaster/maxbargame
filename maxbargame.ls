vertices = (.map ([x, y], i) -> new Vertex i, x, y) [] =
  * 50 10
  * 45 40
  * 70 30
  * 75 50
  * 90 60
  * 80 90
  * 40 85
  * 30 90
  * 10 50
edges = (.map ([s, t, b], i) -> new Edge i, vertices[s], vertices[t], b) [] =
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

players = (.map ([s, t], i) -> new Player i, vertices[s], vertices[t]) [] =
  * 0 6
  * 8 3
  * 5 2

paths = (.map (.map (edges.))) [] =
  * 0 1 2 4
  * 8 9 4
  * 5 4 2

game = maxbargame do
  topology
  players
  allocate topology, paths

x = d3.scale.linear!
  .domain [0 100]
  .range [0 500]

y = d3.scale.linear!
  .domain [0 100]
  .range [0 500]

drag = d3.behavior.drag!
  .on \drag !->
    it.x += x.invert d3.event.dx
    it.y += y.invert d3.event.dy
    draw!

idx = 0

document.get-element-by-id \play-pause
  .add-event-listener \click !->
    idx++
    draw!

alloc-line = (state, users, player, edge) -->
  strategy = state.strategies[player]

  x1 = x edge.0.x
  x2 = x edge.1.x
  y1 = y edge.0.y
  y2 = y edge.1.y

  # adjust to angle of path, so that all allocations on the edge
  # are shown
  offset-start = 0
  for u in users[edge]
    break if u is player
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
  offset *= 4
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

# draw stuff
draw = !->
  state = game[idx]
  users = {}
  for player, strategy of state.strategies
    for edge in strategy.path
      users[][edge]push players[player]

  d3.select \#edges .select-all \.edge .data edges
    ..exit!remove!
    ..enter!append \line .attr \class \edge
    ..attr do
      x1: x << (.0.x)
      y1: y << (.0.y)
      x2: x << (.1.x)
      y2: y << (.1.y)
      \stroke-width : (.bandwidth) >> (*4)
  d3.select \#vertices .select-all \.vertex .data vertices
    ..exit!remove!
    ..enter!append \circle
      .attr \class \vertex
      .call drag
      .on \mouseenter !->
        if it.player?
          d3.select "\#player-#that" .classed \hover true
          d3.select \#topology .classed \dim true
      .on \mouseleave !->
        if it.player?
          d3.select "\#player-#that" .classed \hover false
          d3.select \#topology .classed \dim false
    ..attr do
      cx: x << (.x)
      cy: y << (.y)
      r: -> 2 * d3.max it.edges, (.bandwidth)
  d3.select \#wedges .select-all \.wedges .data vertices
    ..exit!remove!
    ..enter!append \g
      ..attr \class \wedges
    w = ..select-all \.wedge .data ->
      p = []
      for edge in it.edges
        for player in users[edge] || 0
          p.push {player, edge}
      return p
    w
      ..exit!remove!
      ..enter!append \path
      ..attr \class -> "wedge player-#{it.player}"
      ..attr \d ({player, edge}, i, vertex-id) ->
        vertex = vertices[vertex-id]

        cx = x vertex.x
        cy = y vertex.y
        r = 2 * d3.max vertex.edges, (.bandwidth)
        line = alloc-line state, users, player, edge

        {angle, offset-start, offset-end} = line
        offset-start -= edge.bandwidth / 2
        offset-end -= edge.bandwidth / 2
        offset-start *= 4; offset-end *= 4

        if vertex is edge.0
          x2 = x edge.1.x
          y2 = y edge.1.y
          sign = d-sign = 1
        else
          x2 = x edge.0.x
          y2 = y edge.0.y
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
        term = Math.sqrt(r**2 * dr**2 - D**2)
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
    #..select \.start .attr \d (player) ->
      #start = player.0
      #cx = x start.x
      #cy = y start.y
      #r = 2 * d3.max start.edges, (.bandwidth)
      #out-edge = state.strategies[player]path.0
      #line = alloc-line state, users, player, out-edge
      #{angle, offset-start, offset-end} = line
      #offset-start -= out-edge.bandwidth / 2
      #offset-end -= out-edge.bandwidth / 2
      #offset-start *= 4; offset-end *= 4

      #if start is out-edge.0
        #x2 = x out-edge.1.x
        #y2 = y out-edge.1.y
        #sign = d-sign = 1
      #else
        #x2 = x out-edge.0.x
        #y2 = y out-edge.0.y
        #sign = d-sign = -1

      #osx = offset-start * Math.sin angle
      #osy = offset-start * Math.cos angle
      #oex = offset-end * Math.sin angle
      #oey = offset-end * Math.cos angle

      ## intersect offset-start line with circle
      #dx = x2 - cx
      #dy = y2 - cy
      #dr = Math.sqrt dx**2 + dy**2
      #D = osx * (dy + osy) - (dx + osx) * osy
      ## rounding errors cause it to be negative sometimes
      #t = r**2 * dr**2 - D**2
      #t = 0 if t < 0

      #term = Math.sqrt(t)

      #sgn = -> if it < 0 then -1 else 1

      #sign *= if angle > 0 then -1 else 1

      #isx = (D * dy + sign * sgn(dy) * dx * term) / dr**2
      #isy = (-D * dx + sign * Math.abs(dy) * term) / dr**2

      ## offset-end line
      #D = oex * (dy + oey) - (dx + oex) * oey
      #term = Math.sqrt(r**2 * dr**2 - D**2)
      #iex = (D * dy + sign * sgn(dy) * dx * term) / dr**2
      #iey = (-D * dx + sign * Math.abs(dy) * term) / dr**2

      #ddx = iex - isx
      #ddy = iey - isy

      ## center to offset-end, then arc to offset-start, close
      #"
      #M #cx #cy \
      #l #isx #isy \
      #a #r #r 0 0 #{if d-sign > 0 then 1 else 0} #ddx #ddy \
      #Z
      #"
      ##{a #r #r 0 0 1 #iex #iey} \
    #..select \.end .attr \d (player) ->
      #end = player.1
      #cx = x end.x
      #cy = y end.y
      #r = 2 * d3.max end.edges, (.bandwidth)
      #out-edge = state.strategies[player]path[*-1]
      #line = alloc-line state, users, player, out-edge
      #{angle, offset-start, offset-end} = line
      #offset-start -= out-edge.bandwidth / 2
      #offset-end -= out-edge.bandwidth / 2
      #offset-start *= 4; offset-end *= 4

      #if end is out-edge.1
        #x2 = x out-edge.0.x
        #y2 = y out-edge.0.y
        #sign = d-sign = -1
      #else
        #x2 = x out-edge.1.x
        #y2 = y out-edge.1.y
        #sign = d-sign = 1

      #osx = offset-start * Math.sin angle
      #osy = offset-start * Math.cos angle
      #oex = offset-end * Math.sin angle
      #oey = offset-end * Math.cos angle

      ## intersect offset-start line with circle
      #dx = x2 - cx
      #dy = y2 - cy
      #dr = Math.sqrt dx**2 + dy**2
      #D = osx * (dy + osy) - (dx + osx) * osy
      ## rounding errors cause it to be negative sometimes
      #t = r**2 * dr**2 - D**2
      #t = 0 if t < 0

      #term = Math.sqrt(t)

      #sgn = -> if it < 0 then -1 else 1

      #sign *= if angle > 0 then -1 else 1

      #isx = (D * dy + sign * sgn(dy) * dx * term) / dr**2
      #isy = (-D * dx + sign * Math.abs(dy) * term) / dr**2

      ## offset-end line
      #D = oex * (dy + oey) - (dx + oex) * oey
      #term = Math.sqrt(r**2 * dr**2 - D**2)
      #iex = (D * dy + sign * sgn(dy) * dx * term) / dr**2
      #iey = (-D * dx + sign * Math.abs(dy) * term) / dr**2

      #ddx = iex - isx
      #ddy = iey - isy

      ## center to offset-end, then arc to offset-start, close
      #"
      #M #cx #cy \
      #l #isx #isy \
      #a #r #r 0 0 #{if d-sign > 0 then 1 else 0} #ddx #ddy \
      #Z
      #"
      #{a #r #r 0 0 1 #iex #iey} \
  d3.select \#players .select-all \.player .data players
    ..exit!remove!
    ..enter!append \g
      ..attr \class \player
      ..attr \id -> "player-#it"
      ..append \g .attr \class \path
    ..select \.path .each (player) ->
      s = state.strategies[player]

      line = s.path.map alloc-line state, users, player

      d3.select this .select-all \.segment .data line
        ..exit!remove!
        ..enter!append \line .attr \class \segment
        ..attr do
          x1: (.x1)
          y1: (.y1)
          x2: (.x2)
          y2: (.y2)
          \stroke-width : s.bandwidth * 4
        .classed \bottleneck (.bottleneck)

draw!


