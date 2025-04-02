import gleam/dict
import gleam/int
import gleam/io
import gleam/list
import lustre
import lustre/attribute
import lustre/effect
import lustre/element
import lustre/element/html
import lustre/event

pub fn main() {
  lustre.component(init, update, view, dict.new())
}

pub fn init(players) {
  #(
    Model(
      0,
      Draft,
      users: ["Nate", "Josh", "Sam", "Ethan"],
      useronedrafted: [],
      usertwodrafted: [],
      userthreedrafted: [],
      userfourdrafted: [],
      players:,
      playernumber: 1,
      draftpick: 0,
      direction: Forward,
    ),
    effect.none(),
  )
}

pub type Model {
  Model(
    count: Int,
    view_mode: ViewMode,
    users: List(String),
    useronedrafted: List(Player),
    usertwodrafted: List(Player),
    userthreedrafted: List(Player),
    userfourdrafted: List(Player),
    players: List(DraftablePlayer),
    playernumber: Int,
    draftpick: Int,
    direction: Direction,
  )
}

pub type ViewMode {
  TeamView
  Draft
}

pub type Player {
  Player(
    id: Int,
    firstname: String,
    lastname: String,
    position: String,
    team: String,
    adp: Int,
  )
}

pub type DraftablePlayer {
  DraftablePlayer(
    id: Int,
    firstname: String,
    lastname: String,
    position: String,
    team: String,
    adp: Float,
  )
}

pub type Direction {
  Forward
  Backward
}

pub type Msg {
  ToggleView
  IncrementPlayerNumber(DraftablePlayer)
}

pub fn update(model: Model, msg: Msg) {
  case msg {
    ToggleView -> {
      let new_mode = case model.view_mode {
        TeamView -> Draft
        Draft -> TeamView
      }
      #(Model(..model, view_mode: new_mode), effect.none())
    }
    IncrementPlayerNumber(player) -> {
      io.println("picked by " <> int.to_string(model.playernumber))
      io.println("type " <> player.position)

      case model.playernumber {
        1 | 2 | 3 | 4 -> {
          let drafted_list = get_drafted_list(model, model.playernumber)
          let count = count_players(drafted_list, player.position)
          io.println(player.position <> " count: " <> int.to_string(count))

          let is_valid_draft = case player.position, count {
            "QB", 0 -> True
            "QB", 1 -> True
            "TE", 0 -> True
            "TE", 1 -> True
            "WR", 0 -> True
            "WR", 1 -> True
            "WR", 2 -> True
            "RB", 0 -> True
            "RB", 1 -> True
            "RB", 2 -> True
            _, _ -> False
          }

          case is_valid_draft {
            True -> {
              case model.draftpick {
                40 -> #(model, effect.none())
                // If draft pick is 40 dont draft that player
                _ -> {
                  let new_playernumber = case
                    model.direction,
                    model.playernumber
                  {
                    Forward, 1 -> 2
                    Forward, 2 -> 3
                    Forward, 3 -> 4
                    Forward, 4 -> 4
                    Backward, 4 -> 3
                    Backward, 3 -> 2
                    Backward, 2 -> 1
                    Backward, 1 -> 1
                    _, n -> n
                  }

                  let new_direction = case
                    model.direction,
                    model.playernumber,
                    new_playernumber
                  {
                    Forward, 4, 4 -> Backward
                    Backward, 1, 1 -> Forward
                    dir, _, _ -> dir
                  }

                  let new_draftpick = model.draftpick + 1
                  let player_with_updated_adp =
                    Player(
                      id: player.id,
                      firstname: player.firstname,
                      lastname: player.lastname,
                      position: player.position,
                      team: player.team,
                      adp: new_draftpick,
                    )
                  //   Player(..player, adp: new_draftpick)

                  let updated_players =
                    list.filter(model.players, fn(p) { p.id != player.id })
                  let new_model = case model.playernumber {
                    1 ->
                      Model(
                        ..model,
                        useronedrafted: list.append(model.useronedrafted, [
                          player_with_updated_adp,
                        ]),
                      )
                    2 ->
                      Model(
                        ..model,
                        usertwodrafted: list.append(model.usertwodrafted, [
                          player_with_updated_adp,
                        ]),
                      )
                    3 ->
                      Model(
                        ..model,
                        userthreedrafted: list.append(model.userthreedrafted, [
                          player_with_updated_adp,
                        ]),
                      )
                    4 ->
                      Model(
                        ..model,
                        userfourdrafted: list.append(model.userfourdrafted, [
                          player_with_updated_adp,
                        ]),
                      )
                    _ -> model
                  }

                  #(
                    Model(
                      ..new_model,
                      playernumber: new_playernumber,
                      direction: new_direction,
                      players: updated_players,
                      draftpick: new_draftpick,
                    ),
                    effect.none(),
                  )
                }
              }
            }
            False -> {
              io.println("Cannot draft more players of this position")
              #(model, effect.none())
            }
          }
        }
        _ -> {
          io.println("Invalid player number")
          #(model, effect.none())
        }
      }
    }
  }
}

pub fn view(model: Model) -> element.Element(Msg) {
  html.div([attribute.class("min-h-screen w-full bg-header-dark")], [
    html.header(
      [
        attribute.class(
          "p-4 bg-custom-dark text-white flex justify-around items-center",
        ),
      ],
      [
        html.div([], [
          html.h1([attribute.class("text-4xl font-bold")], [
            html.text("Playoff Push"),
          ]),
          html.h3([attribute.class("font-bold pl-2")], [
            html.text("Experience Fantasy Football for the NFL Playoffs"),
          ]),
        ]),
        html.button(
          [event.on_click(ToggleView), attribute.class("btn-primary")],
          [element.text("Switch View")],
        ),
      ],
    ),
    case model.view_mode {
      TeamView ->
        html.div([attribute.class("flex justify-center items-center h-full")], [
          team_view(),
        ])
      Draft ->
        html.div([attribute.class("flex justify-center items-center h-full")], [
          draft_view(
            model,
            model.users,
            model.players,
            model.useronedrafted,
            model.usertwodrafted,
            model.userthreedrafted,
            model.userfourdrafted,
            model.playernumber,
          ),
        ])
    },
  ])
}

fn draft_view(
  model: Model,
  users: List(String),
  players: List(DraftablePlayer),
  useronedrafted: List(Player),
  usertwodrafted: List(Player),
  userthreedrafted: List(Player),
  userfourdrafted: List(Player),
  playernumber: Int,
) -> element.Element(Msg) {
  html.div([attribute.class("p-4 text-white")], [
    html.h2([attribute.class("text-xl mb-4")], [element.text("Draft Board")]),
    html.div([attribute.class("draftBoard")], [
      // round numbers
      html.div([attribute.class("draft")], [
        html.p([attribute.class("mb-2 ml-20")], [html.text("Round 1")]),
        html.div(
          [attribute.class("draft")],
          list.map(list.range(2, 10), fn(round) { round_label(round) }),
        ),
      ]),
      // usernames in draft order
      html.div([attribute.class("flex flex-row")], [
        html.div(
          [attribute.class("users")],
          list.map(users, fn(user) {
            html.p([attribute.class("")], [html.text(user)])
          }),
        ),
        // drafts
        html.div([attribute.class("test")], [
          drafted_users_view(useronedrafted),
          drafted_users_view(usertwodrafted),
          drafted_users_view(userthreedrafted),
          drafted_users_view(userfourdrafted),
        ]),
      ]),
    ]),
    html.div([attribute.class("flex flex-row")], [
      html.div([attribute.class("availablePlayers")], [
        html.div(
          [],
          list.map(players, fn(player) {
            html.div([attribute.class("draftablePlayer")], [
              html.div([], [
                html.p(
                  [
                    attribute.class("draftPlayer"),
                    event.on_click(IncrementPlayerNumber(player)),
                  ],
                  [html.text("+")],
                ),
              ]),
              html.div([], [
                html.p([attribute.class("ml-2 firstName")], [
                  html.text(player.firstname <> " " <> player.lastname),
                ]),
                html.div([attribute.class("posName")], [
                  html.span([attribute.class("ml-2")], [
                    html.text(player.position),
                  ]),
                  html.span([], [html.text(" - ")]),
                  html.span([], [html.text(player.team)]),
                ]),
              ]),
            ])
          }),
        ),
      ]),
      html.div([attribute.class("roster")], [
        html.div([attribute.class("positionHeader")], [
          create_position_box("QB", "quaterback"),
          create_position_box("QB", "quaterback"),
          create_position_box("RB", "runningback"),
          create_position_box("RB", "runningback"),
          create_position_box("RB", "runningback"),
        ]),
        html.div([attribute.class("draftedHeader")], [
          html.div([attribute.class("QBList")], [
            render_position_list(model, model.playernumber, "QB"),
          ]),
          html.div([attribute.class("RBList")], [
            render_position_list(model, model.playernumber, "RB"),
          ]),
        ]),
        html.div([attribute.class("positionHeader")], [
          html.div([attribute.class("position-box widereceiver")], [
            html.span([], [html.text("WR")]),
          ]),
          html.div([attribute.class("position-box widereceiver")], [
            html.span([], [html.text("WR")]),
          ]),
          html.div([attribute.class("position-box widereceiver")], [
            html.span([], [html.text("WR")]),
          ]),
          html.div([attribute.class("position-box tightend")], [
            html.span([], [html.text("TE")]),
          ]),
          html.div([attribute.class("position-box tightend")], [
            html.span([], [html.text("TE")]),
          ]),
        ]),
        html.div([attribute.class("draftedHeader")], [
          html.div([attribute.class("WRList")], [
            render_position_list(model, model.playernumber, "WR"),
          ]),
          html.div([attribute.class("TEList")], [
            render_position_list(model, model.playernumber, "TE"),
          ]),
        ]),
      ]),
    ]),
  ])
}

// Helper functions
// Get the drafted list based on player number
fn get_drafted_list(model: Model, playernumber: Int) -> List(Player) {
  case playernumber {
    1 -> model.useronedrafted
    2 -> model.usertwodrafted
    3 -> model.userthreedrafted
    4 -> model.userfourdrafted
    _ -> []
  }
}

// Count players by position
fn count_players(players: List(Player), position: String) -> Int {
  players
  |> list.filter(fn(player) { player.position == position })
  |> list.length
}

// Get list of position
fn get_position_list(
  model: Model,
  playernumber: Int,
  position: String,
) -> List(Player) {
  let drafted_list = case playernumber {
    1 -> model.useronedrafted
    2 -> model.usertwodrafted
    3 -> model.userthreedrafted
    4 -> model.userfourdrafted
    _ -> []
  }

  list.filter(drafted_list, fn(player) { player.position == position })
}

// Code Functions
fn round_label(round: Int) -> element.Element(Msg) {
  html.p([attribute.class("mb-2")], [
    html.text("Round " <> int.to_string(round)),
  ])
}

fn create_position_box(abbr: String, fullname: String) -> element.Element(msg) {
  html.div([attribute.class("position-box " <> fullname)], [
    html.span([], [element.text(abbr)]),
  ])
}

fn render_position_list(
  model: Model,
  playernumber: Int,
  position: String,
) -> element.Element(Msg) {
  let qb_players = get_position_list(model, playernumber, position)

  html.div(
    [],
    list.map(qb_players, fn(player) {
      html.p([attribute.class("drafted")], [
        element.text(player.firstname <> " " <> player.lastname),
      ])
    }),
  )
}

fn drafted_users_view(players: List(Player)) -> element.Element(Msg) {
  html.div([], [
    html.div(
      [attribute.class("flex flex-row")],
      list.map(players, fn(player) {
        html.div([attribute.class(player.position)], [
          html.div([attribute.class("playerHeader")], [
            html.div([], [
              html.span([attribute.class("ml-2")], [html.text(player.position)]),
              html.span([], [html.text(" - ")]),
              html.span([], [html.text(player.team)]),
            ]),
            html.div([], [
              html.span([attribute.class("ml-2")], [
                html.text(int.to_string(player.adp)),
              ]),
            ]),
          ]),
          html.p([attribute.class("ml-2 firstName")], [
            html.text(player.firstname),
          ]),
          html.p([attribute.class("ml-2 lastName")], [
            html.text(player.lastname),
          ]),
        ])
      }),
    ),
  ])
}

fn team_view() -> element.Element(Msg) {
  html.div([attribute.class("text-white p-4")], [
    html.p([], [element.text("show teams")]),
  ])
}
