import dot_env
import dot_env/env
import gleam/dict
import gleam/dynamic/decode
import gleam/erlang/process
import gleam/http
import gleam/int
import gleam/io
import gleam/json
import gleam/list
import gleam/option
import gleam/string
import gleam/string_tree
import gleam/uri
import mist
import sqlight
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

  let rowjson =
    json.object([
      #("playerid", json.int(playerid)),
      #("firstname", json.string(firstname)),
      #("lastname", json.string(lastname)),
      #("position", json.string(position)),
      #("team", json.string(team)),
      #("adp", json.float(adp)),
    ])
  decode.success(rowjson)
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

pub fn main() {
  wisp.configure_logger()

  dot_env.new()
  |> dot_env.set_path(".env")
  |> dot_env.set_debug(False)
  |> dot_env.load
  let assert Ok(secret_key_base) = env.get_string("SECRET_KEY_BASE")

  // Define the request handler
  let handler = fn(req) {
    case wisp.path_segments(req) {
      [] -> {
        wisp.html_response(string_tree.from_string("Hello"), 200)
      }
      ["getDraftablePlayers"] -> {
        io.debug("Fetching draftable players")

        let assert Ok(conn) = sqlight.open("playoffpush.db")
        let sql = "SELECT * FROM DraftablePlayer ORDER BY adp DESC;"

        let assert Ok(rows) =
          sqlight.query(
            sql,
            on: conn,
            with: [],
            expecting: draftableplayer_endec(),
          )

        let draftableplayers_json = json.preprocessed_array(rows)
        json.to_string_tree(draftableplayers_json)
        |> wisp.json_response(200)
        |> wisp.set_header("access-control-allow-origin", "*")
      }
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
        let sql =
          "SELECT * FROM UserTeam WHERE leagueid = ? AND usernumber = ?;"

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

  // Start the HTTP server
  let assert Ok(_) =
    wisp_mist.handler(handler, secret_key_base)
    |> mist.new
    |> mist.port(8000)
    |> mist.start_http
  process.sleep_forever()
}
