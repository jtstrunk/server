import gleam/dict
import gleam/float
import gleam/int
import gleam/io
import gleam/list
import gleam/result
import lustre
import lustre/attribute
import lustre/effect
import lustre/element
import lustre/element/html
import lustre/event

pub fn main() {
  lustre.component(init, update, view, dict.new())
}

pub fn init(flags) {
  let groups = list.group(flags, by: fn(i: UserTeam) { i.usernumber })

  #(
    Model(
      users: ["Nate", "Josh", "Sam", "Ethan"],
      useronedrafted: dict.get(groups, 1) |> result.unwrap([]),
      usertwodrafted: dict.get(groups, 2) |> result.unwrap([]),
      userthreedrafted: dict.get(groups, 3) |> result.unwrap([]),
      userfourdrafted: dict.get(groups, 4) |> result.unwrap([]),
    ),
    effect.none(),
  )
}

pub type Model {
  Model(
    users: List(String),
    useronedrafted: List(UserTeam),
    usertwodrafted: List(UserTeam),
    userthreedrafted: List(UserTeam),
    userfourdrafted: List(UserTeam),
  )
}

pub type UserTeam {
  UserTeam(
    leagueid: Int,
    usernumber: Int,
    firstname: String,
    lastname: String,
    team: String,
    position: String,
    wildcardpoints: Float,
    divisionalpoints: Float,
    championshippoints: Float,
    superbowlpoints: Float,
  )
}

pub type Msg

pub fn update(model: Model, msg: Msg) {
  case msg {
    _ -> #(model, effect.none())
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
      ],
    ),
    html.div([attribute.class("flex justify-center items-center h-full")], [
      team_view(model, model.users),
    ]),
  ])
}

// Helper functions
// Get list of position
fn get_position_list(
  model: Model,
  playernumber: Int,
  position: String,
) -> List(UserTeam) {
  let drafted_list = case playernumber {
    1 -> model.useronedrafted
    2 -> model.usertwodrafted
    3 -> model.userthreedrafted
    4 -> model.userfourdrafted
    _ -> []
  }

  list.filter(drafted_list, fn(player) { player.position == position })
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
  let players = get_position_list(model, playernumber, position)

  html.div(
    [],
    list.map(players, fn(player) {
      html.div([attribute.class("flex flex-row")], [
        html.p([attribute.class("drafted")], [
          element.text(player.firstname <> " " <> player.lastname),
        ]),
        html.div([attribute.class("flex flex-row pointsSection")], [
          html.p([attribute.class("points")], [
            element.text(float.to_string(player.wildcardpoints)),
          ]),
          html.p([attribute.class("points")], [
            element.text(float.to_string(player.divisionalpoints)),
          ]),
          html.p([attribute.class("points")], [
            element.text(float.to_string(player.championshippoints)),
          ]),
          html.p([attribute.class("points")], [
            element.text(float.to_string(player.superbowlpoints)),
          ]),
          html.p([attribute.class("points")], [element.text("271.5")]),
        ]),
      ])
    }),
  )
}

fn team_view(model: Model, users: List(String)) -> element.Element(Msg) {
  html.div([attribute.class("text-white p-4 ")], [
    html.div([attribute.class("flex flex-col teams")], [
      html.div([attribute.class("flex flex-row playerSection")], [
        html.div([attribute.class("test")], [
          html.div([attribute.class("flex flex-row")], [
            html.div([attribute.class("flex flex-row playerName")], [
              html.p([attribute.class("")], [html.text("Nate - &nbsp;")]),
              html.p([attribute.class("")], [html.text("0")]),
            ]),
            html.div([attribute.class("flex flex-row teamHeading")], [
              html.p([attribute.class("")], [html.text("WC")]),
              html.p([attribute.class("")], [html.text("DIV")]),
              html.p([attribute.class("")], [html.text("CHAMP")]),
              html.p([attribute.class("")], [html.text("SOUPY")]),
              html.p([attribute.class("")], [html.text("TOTAL")]),
            ]),
          ]),
          html.div([attribute.class("flex flex-row player")], [
            html.div([], [
              create_position_box("QB", "quaterback"),
              create_position_box("QB", "quaterback"),
              create_position_box("RB", "runningback"),
              create_position_box("RB", "runningback"),
              create_position_box("RB", "runningback"),
              create_position_box("WR", "widereceiver"),
              create_position_box("WR", "widereceiver"),
              create_position_box("WR", "widereceiver"),
              create_position_box("TE", "tightend"),
              create_position_box("TE", "tightend"),
            ]),
            html.div([], [
              html.div([attribute.class("QBList")], [
                render_position_list(model, 1, "QB"),
              ]),
              html.div([attribute.class("WRList")], [
                render_position_list(model, 1, "RB"),
              ]),
              html.div([attribute.class("WRList")], [
                render_position_list(model, 1, "WR"),
              ]),
              html.div([attribute.class("TEList")], [
                render_position_list(model, 1, "TE"),
              ]),
            ]),
          ]),
        ]),
        html.div([attribute.class("test")], [
          html.div([attribute.class("flex flex-row")], [
            html.div([attribute.class("flex flex-row playerName")], [
              html.p([attribute.class("")], [html.text("Josh - ")]),
              html.p([attribute.class("")], [html.text("0")]),
            ]),
            html.div([attribute.class("flex flex-row teamHeading")], [
              html.p([attribute.class("")], [html.text("WC")]),
              html.p([attribute.class("")], [html.text("DIV")]),
              html.p([attribute.class("")], [html.text("CHAMP")]),
              html.p([attribute.class("")], [html.text("SOUPY")]),
              html.p([attribute.class("")], [html.text("TOTAL")]),
            ]),
          ]),
          html.div([attribute.class("flex flex-row player")], [
            html.div([], [
              create_position_box("QB", "quaterback"),
              create_position_box("QB", "quaterback"),
              create_position_box("RB", "runningback"),
              create_position_box("RB", "runningback"),
              create_position_box("RB", "runningback"),
              create_position_box("WR", "widereceiver"),
              create_position_box("WR", "widereceiver"),
              create_position_box("WR", "widereceiver"),
              create_position_box("TE", "tightend"),
              create_position_box("TE", "tightend"),
            ]),
            html.div([], [
              html.div([attribute.class("QBList")], [
                render_position_list(model, 2, "QB"),
              ]),
              html.div([attribute.class("WRList")], [
                render_position_list(model, 2, "RB"),
              ]),
              html.div([attribute.class("WRList")], [
                render_position_list(model, 2, "WR"),
              ]),
              html.div([attribute.class("TEList")], [
                render_position_list(model, 2, "TE"),
              ]),
            ]),
          ]),
        ]),
      ]),
      html.div([attribute.class("flex flex-row playerSection")], [
        html.div([attribute.class("test")], [
          html.div([attribute.class("flex flex-row")], [
            html.div([attribute.class("flex flex-row playerName")], [
              html.p([attribute.class("")], [html.text("Sam - ")]),
              html.p([attribute.class("")], [html.text("0")]),
            ]),
            html.div([attribute.class("flex flex-row teamHeading")], [
              html.p([attribute.class("")], [html.text("WC")]),
              html.p([attribute.class("")], [html.text("DIV")]),
              html.p([attribute.class("")], [html.text("CHAMP")]),
              html.p([attribute.class("")], [html.text("SOUPY")]),
              html.p([attribute.class("")], [html.text("TOTAL")]),
            ]),
          ]),
          html.div([attribute.class("flex flex-row player")], [
            html.div([], [
              create_position_box("QB", "quaterback"),
              create_position_box("QB", "quaterback"),
              create_position_box("RB", "runningback"),
              create_position_box("RB", "runningback"),
              create_position_box("RB", "runningback"),
              create_position_box("WR", "widereceiver"),
              create_position_box("WR", "widereceiver"),
              create_position_box("WR", "widereceiver"),
              create_position_box("TE", "tightend"),
              create_position_box("TE", "tightend"),
            ]),
            html.div([], [
              html.div([attribute.class("QBList")], [
                render_position_list(model, 3, "QB"),
              ]),
              html.div([attribute.class("WRList")], [
                render_position_list(model, 3, "RB"),
              ]),
              html.div([attribute.class("WRList")], [
                render_position_list(model, 3, "WR"),
              ]),
              html.div([attribute.class("TEList")], [
                render_position_list(model, 3, "TE"),
              ]),
            ]),
          ]),
        ]),
        html.div([attribute.class("test")], [
          html.div([attribute.class("flex flex-row")], [
            html.div([attribute.class("flex flex-row playerName")], [
              html.p([attribute.class("")], [html.text("Ethan - ")]),
              html.p([attribute.class("")], [html.text("0")]),
            ]),
            html.div([attribute.class("flex flex-row teamHeading")], [
              html.p([attribute.class("")], [html.text("WC")]),
              html.p([attribute.class("")], [html.text("DIV")]),
              html.p([attribute.class("")], [html.text("CHAMP")]),
              html.p([attribute.class("")], [html.text("SOUPY")]),
              html.p([attribute.class("")], [html.text("TOTAL")]),
            ]),
          ]),
          html.div([attribute.class("flex flex-row player")], [
            html.div([], [
              create_position_box("QB", "quaterback"),
              create_position_box("QB", "quaterback"),
              create_position_box("RB", "runningback"),
              create_position_box("RB", "runningback"),
              create_position_box("RB", "runningback"),
              create_position_box("WR", "widereceiver"),
              create_position_box("WR", "widereceiver"),
              create_position_box("WR", "widereceiver"),
              create_position_box("TE", "tightend"),
              create_position_box("TE", "tightend"),
            ]),
            html.div([], [
              html.div([attribute.class("QBList")], [
                render_position_list(model, 4, "QB"),
              ]),
              html.div([attribute.class("WRList")], [
                render_position_list(model, 4, "RB"),
              ]),
              html.div([attribute.class("WRList")], [
                render_position_list(model, 4, "WR"),
              ]),
              html.div([attribute.class("TEList")], [
                render_position_list(model, 4, "TE"),
              ]),
            ]),
          ]),
        ]),
      ]),
    ]),
  ])
}
