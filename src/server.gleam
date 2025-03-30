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
import gleam/string_tree
import gleam/uri
import mist
import sqlight
import wisp
import wisp/wisp_mist

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
