import clientcode
import dot_env
import dot_env/env
import gleam/dict
import gleam/dynamic
import gleam/dynamic/decode
import gleam/erlang/process
import gleam/http
import gleam/http/request
import gleam/int
import gleam/io
import gleam/json
import gleam/list
import gleam/option
import gleam/string
import gleam/string_tree
import gleam/uri
import lustre
import lustre/server_component as lustre_server_component
import mist
import server_component
import sqlight
import teamview
import wisp
import wisp/wisp_mist

fn insert_decoder() {
  use leagueid <- decode.field("leagueid", decode.int)
  use usernumber <- decode.field("usernumber", decode.int)
  use playerfirstname <- decode.field("playerfirstname", decode.string)
  use playerlastname <- decode.field("playerlastname", decode.string)
  use playerteam <- decode.field("playerteam", decode.string)
  use playerposition <- decode.field("playerposition", decode.string)
  use playerdraftnumber <- decode.field("playerdraftnumber", decode.int)

  decode.success(#(
    leagueid,
    usernumber,
    playerfirstname,
    playerlastname,
    playerteam,
    playerposition,
    playerdraftnumber,
  ))
}

pub fn draftableplayer_endec() {
  use playerid <- decode.field(0, decode.int)
  use firstname <- decode.field(1, decode.string)
  use lastname <- decode.field(2, decode.string)
  use position <- decode.field(3, decode.string)
  use team <- decode.field(4, decode.string)
  use adp <- decode.field(5, decode.float)

  decode.success(clientcode.DraftablePlayer(
    playerid,
    firstname,
    lastname,
    position,
    team,
    adp,
  ))
  // let rowjson =
  //   json.object([
  //     #("playerid", json.int(playerid)),
  //     #("firstname", json.string(firstname)),
  //     #("lastname", json.string(lastname)),
  //     #("position", json.string(position)),
  //     #("team", json.string(team)),
  //     #("adp", json.float(adp)),
  //   ])
  // decode.success(rowjson)
}

pub fn userteam_endectest() {
  use leagueid <- decode.field(0, decode.int)
  use usernumber <- decode.field(1, decode.int)
  use firstname <- decode.field(2, decode.string)
  use lastname <- decode.field(3, decode.string)
  use team <- decode.field(4, decode.string)
  use position <- decode.field(5, decode.string)
  use wildcardpoints <- decode.field(6, number_as_float())
  use divisionalpoints <- decode.field(7, number_as_float())
  use championshippoints <- decode.field(8, number_as_float())
  use superbowlpoints <- decode.field(9, number_as_float())

  decode.success(teamview.UserTeam(
    leagueid,
    usernumber,
    firstname,
    lastname,
    team,
    position,
    wildcardpoints,
    divisionalpoints,
    championshippoints,
    superbowlpoints,
  ))
}

pub fn userteam_endec() {
  use leagueid <- decode.field(0, decode.int)
  use usernumber <- decode.field(1, decode.int)
  use firstname <- decode.field(2, decode.string)
  use lastname <- decode.field(3, decode.string)
  use team <- decode.field(4, decode.string)
  use position <- decode.field(5, decode.string)
  use playerdraftnumber <- decode.field(6, decode.string)

  let rowjson =
    json.object([
      #("leagueid", json.int(leagueid)),
      #("usernumber", json.int(usernumber)),
      #("firstname", json.string(firstname)),
      #("lastname", json.string(lastname)),
      #("team", json.string(team)),
      #("position", json.string(position)),
      #("draftpositon", json.string(playerdraftnumber)),
    ])
  decode.success(rowjson)
}

pub fn number_as_float() {
  decode.one_of(decode.float, [decode.int |> decode.map(int.to_float)])
}

// pub fn number_asint(dy) {
//   case dynamic.int(dy) {
//     Ok(val) -> Ok(val)
//     Error() -> {
//       case dynamic.float(dy) {
//         Error(err) -> Error(err)
//         Ok(val) -> Ok(float.truncate(val))
//       }
//     }
//   }
// }

pub type Context {
  Context(
    draft_actor: process.Subject(
      lustre.Action(clientcode.Msg, lustre.ServerComponent),
    ),
    team_actor: process.Subject(
      lustre.Action(teamview.Msg, lustre.ServerComponent),
    ),
  )
}

pub fn main() {
  wisp.configure_logger()

  dot_env.new()
  |> dot_env.set_path(".env")
  |> dot_env.set_debug(False)
  |> dot_env.load
  let assert Ok(secret_key_base) = env.get_string("SECRET_KEY_BASE")

  let assert Ok(conn) = sqlight.open("playoffpush.db")
  let sql = "SELECT * FROM DraftablePlayer ORDER BY adp DESC;"

  let assert Ok(draftableplayerrows) =
    sqlight.query(sql, on: conn, with: [], expecting: draftableplayer_endec())

  let leagueid = 25_226
  let sql = "SELECT * FROM UserTeam WHERE leagueid = ?;"

  let assert Ok(teamrows) =
    sqlight.query(
      sql,
      on: conn,
      with: [sqlight.int(leagueid)],
      expecting: userteam_endectest(),
    )

  echo "query results"
  echo teamrows

  let assert Ok(draft_actor) =
    lustre.start_actor(clientcode.main(), draftableplayerrows)
  let assert Ok(team_actor) = lustre.start_actor(teamview.main(), teamrows)
  let context = Context(draft_actor:, team_actor:)

  // Start the HTTP server
  let mist_handler = fn(req) { handler(req, context, secret_key_base) }

  let assert Ok(_) =
    mist_handler
    |> mist.new
    |> mist.port(8100)
    |> mist.bind("0.0.0.0")
    |> mist.start_http
  process.sleep_forever()
}

fn handler(req, context: Context, secret_key_base) {
  case request.path_segments(req) {
    ["client.css" as css] | ["customClient.css" as css] ->
      server_component.serve_css(css)

    ["draft-server-component"] ->
      server_component.get_connection(req, context.draft_actor)

    ["team-server-component"] ->
      server_component.get_connection(req, context.team_actor)

    ["draft"] -> server_component.render_as_page("draft-server-component")

    ["teams"] -> server_component.render_as_page("team-server-component")

    _ ->
      wisp_mist.handler(handle_wisp_request(_, context), secret_key_base)(req)
  }
}

fn handle_wisp_request(req, _context) {
  case wisp.path_segments(req) {
    [] -> {
      wisp.html_response(string_tree.from_string("Hello"), 200)
    }

    // ["getDraftablePlayers"] -> {
    //   io.debug("Fetching draftable players")
    //   let assert Ok(conn) = sqlight.open("playoffpush.db")
    //   let sql = "SELECT * FROM DraftablePlayer ORDER BY adp DESC;"
    //   let assert Ok(rows) =
    //     sqlight.query(
    //       sql,
    //       on: conn,
    //       with: [],
    //       expecting: draftableplayer_endec(),
    //     )
    //   let draftableplayers_json = json.preprocessed_array(rows)
    //   json.to_string_tree(draftableplayers_json)
    //   |> wisp.json_response(200)
    //   |> wisp.set_header("access-control-allow-origin", "*")
    // }
    ["getUserTeam", encoded_usernnumber] -> {
      io.debug("Fetching a user's team")
      let usernnumberstring = case uri.percent_decode(encoded_usernnumber) {
        Ok(decoded_name) -> decoded_name
        Error(_) -> "Invalid name"
      }
      let new_usernnumber = int.parse(usernnumberstring)
      let usernnumber = case new_usernnumber {
        Ok(number) -> number
        // Extract the integer if parsing was successful
        Error(_) -> -1
        // Use a default value (e.g., -1) if parsing failed
      }

      let leagueid = 25_226

      let assert Ok(conn) = sqlight.open("playoffpush.db")
      let sql = "SELECT * FROM UserTeam WHERE leagueid = ?;"

      let assert Ok(rows) =
        sqlight.query(
          sql,
          on: conn,
          with: [sqlight.int(leagueid), sqlight.int(usernnumber)],
          expecting: userteam_endec(),
        )

      let draftableplayers_json = json.preprocessed_array(rows)
      json.to_string_tree(draftableplayers_json)
      |> wisp.json_response(200)
      |> wisp.set_header("access-control-allow-origin", "*")
    }
    ["draftPlayer"] -> {
      case req.method {
        http.Options -> {
          wisp.ok()
          |> wisp.set_header("access-control-allow-origin", "*")
          |> wisp.set_header("access-control-allow-methods", "POST, OPTIONS")
          |> wisp.set_header("access-control-allow-headers", "Content-Type")
        }
        http.Post -> {
          io.debug("drafting player")
          use json_result <- wisp.require_json(req)
          let assert Ok(#(
            leagueid,
            usernumber,
            playerfirstname,
            playerlastname,
            playerteam,
            playerposition,
            playerdraftnumber,
          )) = decode.run(json_result, insert_decoder())

          let assert Ok(conn) = sqlight.open("playoffpush.db")

          let sql =
            "INSERT INTO UserTeam (leagueid, usernumber, playerfirstname, playerlastname, playerteam, playerposition, playerdraftnumber)
              VALUES (?, ?, ?, ?, ?, ?, ?)"

          let _ =
            io.debug(
              sqlight.query(sql, conn, decode.int, with: [
                sqlight.int(leagueid),
                sqlight.int(usernumber),
                sqlight.text(playerfirstname),
                sqlight.text(playerlastname),
                sqlight.text(playerteam),
                sqlight.text(playerposition),
                sqlight.int(playerdraftnumber),
              ]),
            )

          let inserted_game_json =
            json.object([
              #("leagueid", json.int(leagueid)),
              #("event", json.string("Inserted")),
            ])

          json.to_string_tree(inserted_game_json)
          |> wisp.json_response(200)
          |> wisp.set_header("access-control-allow-origin", "*")
          |> wisp.set_header("access-control-allow-methods", "POST, OPTIONS")
          |> wisp.set_header("access-control-allow-headers", "Content-Type")
        }
        _ -> wisp.method_not_allowed([http.Options, http.Post])
      }
      // io.debug("drafting player")

      // let assert Ok(conn) = sqlight.open("playoffpush.db")
      // let sql = "SELECT * FROM DraftablePlayer ORDER BY adp DESC;"

      // let assert Ok(rows) =
      //   sqlight.query(
      //     sql,
      //     on: conn,
      //     with: [],
      //     expecting: draftableplayer_endec(),
      //   )

      // let draftableplayers_json = json.preprocessed_array(rows)

      // json.to_string_tree(draftableplayers_json)
      // |> wisp.json_response(200)
      // |> wisp.set_header("access-control-allow-origin", "*")
    }

    _ -> wisp.not_found()
  }
}
