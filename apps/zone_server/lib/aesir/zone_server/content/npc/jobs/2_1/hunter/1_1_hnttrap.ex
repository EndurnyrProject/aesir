defmodule Aesir.ZoneServer.Content.Npc.Jobs.M21.Hunter.M11Hnttrap do
  @moduledoc """
  Hunter test trap that sends a careless examinee back to the starting point.

  ## Behavior

  - Broadcasts one of many randomly chosen taunts naming the examinee.
  - Resets the examinee's test progress and returns them to the waiting area.
  - Resets the test arena and reopens the waiting room.

  ## Credits

  - Original from rAthena, authors and Contributors
    - EREMES THE CANIVALIZER
    - yoshiki
    - kobra_k88
    - Lupus
    - celest
    - Poki#3
    - Vicious
    - Silent
    - FlavioJS
    - Samuray22
    - L0ne_W0lf
    - Kisuka
    - Vali

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "job_hunte",
        x: 52,
        y: 140,
        dir: 0,
        sprite: -1,
        name: "1-1::HntTrap",
        scope: :shared,
        unique_name: "HntTrap",
        trigger: {0, 1}
      },
      %{
        map: "job_hunte",
        x: 53,
        y: 140,
        dir: 0,
        sprite: -1,
        name: "1-2",
        scope: :shared,
        trigger: {0, 1}
      },
      %{
        map: "job_hunte",
        x: 54,
        y: 141,
        dir: 0,
        sprite: -1,
        name: "1-3",
        scope: :shared,
        trigger: {0, 0}
      },
      %{
        map: "job_hunte",
        x: 55,
        y: 141,
        dir: 0,
        sprite: -1,
        name: "1-4",
        scope: :shared,
        trigger: {0, 0}
      },
      %{
        map: "job_hunte",
        x: 55,
        y: 140,
        dir: 0,
        sprite: -1,
        name: "1-5",
        scope: :shared,
        trigger: {0, 0}
      },
      %{
        map: "job_hunte",
        x: 54,
        y: 140,
        dir: 0,
        sprite: -1,
        name: "1-6",
        scope: :shared,
        trigger: {0, 0}
      },
      %{
        map: "job_hunte",
        x: 52,
        y: 138,
        dir: 0,
        sprite: -1,
        name: "1-7",
        scope: :shared,
        trigger: {0, 0}
      },
      %{
        map: "job_hunte",
        x: 53,
        y: 138,
        dir: 0,
        sprite: -1,
        name: "1-8",
        scope: :shared,
        trigger: {0, 0}
      },
      %{
        map: "job_hunte",
        x: 62,
        y: 140,
        dir: 0,
        sprite: -1,
        name: "2-1",
        scope: :shared,
        trigger: {0, 1}
      },
      %{
        map: "job_hunte",
        x: 63,
        y: 140,
        dir: 0,
        sprite: -1,
        name: "2-2",
        scope: :shared,
        trigger: {0, 1}
      },
      %{
        map: "job_hunte",
        x: 64,
        y: 140,
        dir: 0,
        sprite: -1,
        name: "2-3",
        scope: :shared,
        trigger: {0, 0}
      },
      %{
        map: "job_hunte",
        x: 64,
        y: 141,
        dir: 0,
        sprite: -1,
        name: "2-4",
        scope: :shared,
        trigger: {0, 0}
      },
      %{
        map: "job_hunte",
        x: 65,
        y: 140,
        dir: 0,
        sprite: -1,
        name: "2-5",
        scope: :shared,
        trigger: {0, 0}
      },
      %{
        map: "job_hunte",
        x: 65,
        y: 141,
        dir: 0,
        sprite: -1,
        name: "2-6",
        scope: :shared,
        trigger: {0, 0}
      },
      %{
        map: "job_hunte",
        x: 62,
        y: 138,
        dir: 0,
        sprite: -1,
        name: "2-7",
        scope: :shared,
        trigger: {0, 0}
      },
      %{
        map: "job_hunte",
        x: 63,
        y: 138,
        dir: 0,
        sprite: -1,
        name: "2-8",
        scope: :shared,
        trigger: {0, 0}
      },
      %{
        map: "job_hunte",
        x: 72,
        y: 140,
        dir: 0,
        sprite: -1,
        name: "3-1",
        scope: :shared,
        trigger: {0, 1}
      },
      %{
        map: "job_hunte",
        x: 73,
        y: 140,
        dir: 0,
        sprite: -1,
        name: "3-2",
        scope: :shared,
        trigger: {0, 1}
      },
      %{
        map: "job_hunte",
        x: 72,
        y: 138,
        dir: 0,
        sprite: -1,
        name: "3-3",
        scope: :shared,
        trigger: {0, 0}
      },
      %{
        map: "job_hunte",
        x: 72,
        y: 138,
        dir: 0,
        sprite: -1,
        name: "3-4",
        scope: :shared,
        trigger: {0, 0}
      },
      %{
        map: "job_hunte",
        x: 78,
        y: 140,
        dir: 0,
        sprite: -1,
        name: "4-1",
        scope: :shared,
        trigger: {0, 0}
      },
      %{
        map: "job_hunte",
        x: 78,
        y: 141,
        dir: 0,
        sprite: -1,
        name: "4-2",
        scope: :shared,
        trigger: {0, 0}
      },
      %{
        map: "job_hunte",
        x: 79,
        y: 140,
        dir: 0,
        sprite: -1,
        name: "4-3",
        scope: :shared,
        trigger: {0, 0}
      },
      %{
        map: "job_hunte",
        x: 79,
        y: 141,
        dir: 0,
        sprite: -1,
        name: "4-4",
        scope: :shared,
        trigger: {0, 0}
      },
      %{
        map: "job_hunte",
        x: 82,
        y: 138,
        dir: 0,
        sprite: -1,
        name: "5-1",
        scope: :shared,
        trigger: {0, 0}
      },
      %{
        map: "job_hunte",
        x: 82,
        y: 139,
        dir: 0,
        sprite: -1,
        name: "5-2",
        scope: :shared,
        trigger: {0, 0}
      },
      %{
        map: "job_hunte",
        x: 83,
        y: 138,
        dir: 0,
        sprite: -1,
        name: "5-3",
        scope: :shared,
        trigger: {0, 0}
      },
      %{
        map: "job_hunte",
        x: 83,
        y: 139,
        dir: 0,
        sprite: -1,
        name: "5-4",
        scope: :shared,
        trigger: {0, 0}
      },
      %{
        map: "job_hunte",
        x: 99,
        y: 138,
        dir: 0,
        sprite: -1,
        name: "6-1",
        scope: :shared,
        trigger: {1, 0}
      },
      %{
        map: "job_hunte",
        x: 99,
        y: 139,
        dir: 0,
        sprite: -1,
        name: "6-2",
        scope: :shared,
        trigger: {1, 0}
      },
      %{
        map: "job_hunte",
        x: 101,
        y: 138,
        dir: 0,
        sprite: -1,
        name: "6-3",
        scope: :shared,
        trigger: {0, 0}
      },
      %{
        map: "job_hunte",
        x: 101,
        y: 139,
        dir: 0,
        sprite: -1,
        name: "6-4",
        scope: :shared,
        trigger: {0, 0}
      },
      %{
        map: "job_hunte",
        x: 106,
        y: 140,
        dir: 0,
        sprite: -1,
        name: "7-1",
        scope: :shared,
        trigger: {0, 1}
      },
      %{
        map: "job_hunte",
        x: 107,
        y: 140,
        dir: 0,
        sprite: -1,
        name: "7-2",
        scope: :shared,
        trigger: {0, 1}
      },
      %{
        map: "job_hunte",
        x: 106,
        y: 138,
        dir: 0,
        sprite: -1,
        name: "7-3",
        scope: :shared,
        trigger: {0, 0}
      },
      %{
        map: "job_hunte",
        x: 107,
        y: 138,
        dir: 0,
        sprite: -1,
        name: "7-4",
        scope: :shared,
        trigger: {0, 0}
      },
      %{
        map: "job_hunte",
        x: 112,
        y: 140,
        dir: 0,
        sprite: -1,
        name: "8-1",
        scope: :shared,
        trigger: {0, 0}
      },
      %{
        map: "job_hunte",
        x: 112,
        y: 141,
        dir: 0,
        sprite: -1,
        name: "8-2",
        scope: :shared,
        trigger: {0, 0}
      },
      %{
        map: "job_hunte",
        x: 113,
        y: 140,
        dir: 0,
        sprite: -1,
        name: "8-3",
        scope: :shared,
        trigger: {0, 0}
      },
      %{
        map: "job_hunte",
        x: 113,
        y: 141,
        dir: 0,
        sprite: -1,
        name: "8-4",
        scope: :shared,
        trigger: {0, 0}
      },
      %{
        map: "job_hunte",
        x: 116,
        y: 140,
        dir: 0,
        sprite: -1,
        name: "9-1",
        scope: :shared,
        trigger: {0, 0}
      },
      %{
        map: "job_hunte",
        x: 116,
        y: 141,
        dir: 0,
        sprite: -1,
        name: "9-2",
        scope: :shared,
        trigger: {0, 0}
      },
      %{
        map: "job_hunte",
        x: 117,
        y: 140,
        dir: 0,
        sprite: -1,
        name: "9-3",
        scope: :shared,
        trigger: {0, 0}
      },
      %{
        map: "job_hunte",
        x: 117,
        y: 141,
        dir: 0,
        sprite: -1,
        name: "9-4",
        scope: :shared,
        trigger: {0, 0}
      },
      %{
        map: "job_hunte",
        x: 120,
        y: 138,
        dir: 0,
        sprite: -1,
        name: "10-1",
        scope: :shared,
        trigger: {0, 0}
      },
      %{
        map: "job_hunte",
        x: 120,
        y: 139,
        dir: 0,
        sprite: -1,
        name: "10-2",
        scope: :shared,
        trigger: {0, 0}
      },
      %{
        map: "job_hunte",
        x: 121,
        y: 138,
        dir: 0,
        sprite: -1,
        name: "10-3",
        scope: :shared,
        trigger: {0, 0}
      },
      %{
        map: "job_hunte",
        x: 121,
        y: 139,
        dir: 0,
        sprite: -1,
        name: "10-4",
        scope: :shared,
        trigger: {0, 0}
      },
      %{
        map: "job_hunte",
        x: 126,
        y: 139,
        dir: 0,
        sprite: -1,
        name: "11-1",
        scope: :shared,
        trigger: {0, 2}
      },
      %{
        map: "job_hunte",
        x: 127,
        y: 139,
        dir: 0,
        sprite: -1,
        name: "11-2",
        scope: :shared,
        trigger: {0, 2}
      },
      %{
        map: "job_hunte",
        x: 126,
        y: 136,
        dir: 0,
        sprite: -1,
        name: "11-3",
        scope: :shared,
        trigger: {0, 0}
      },
      %{
        map: "job_hunte",
        x: 127,
        y: 136,
        dir: 0,
        sprite: -1,
        name: "11-4",
        scope: :shared,
        trigger: {0, 0}
      },
      %{
        map: "job_hunte",
        x: 52,
        y: 134,
        dir: 0,
        sprite: -1,
        name: "12-1",
        scope: :shared,
        trigger: {0, 1}
      },
      %{
        map: "job_hunte",
        x: 53,
        y: 134,
        dir: 0,
        sprite: -1,
        name: "12-2",
        scope: :shared,
        trigger: {0, 1}
      },
      %{
        map: "job_hunte",
        x: 52,
        y: 132,
        dir: 0,
        sprite: -1,
        name: "12-3",
        scope: :shared,
        trigger: {0, 0}
      },
      %{
        map: "job_hunte",
        x: 53,
        y: 132,
        dir: 0,
        sprite: -1,
        name: "12-4",
        scope: :shared,
        trigger: {0, 0}
      },
      %{
        map: "job_hunte",
        x: 124,
        y: 130,
        dir: 0,
        sprite: -1,
        name: "13-1",
        scope: :shared,
        trigger: {0, 0}
      },
      %{
        map: "job_hunte",
        x: 124,
        y: 131,
        dir: 0,
        sprite: -1,
        name: "13-2",
        scope: :shared,
        trigger: {0, 0}
      },
      %{
        map: "job_hunte",
        x: 125,
        y: 130,
        dir: 0,
        sprite: -1,
        name: "13-3",
        scope: :shared,
        trigger: {0, 0}
      },
      %{
        map: "job_hunte",
        x: 125,
        y: 131,
        dir: 0,
        sprite: -1,
        name: "13-4",
        scope: :shared,
        trigger: {0, 0}
      },
      %{
        map: "job_hunte",
        x: 64,
        y: 128,
        dir: 0,
        sprite: -1,
        name: "14-1",
        scope: :shared,
        trigger: {0, 0}
      },
      %{
        map: "job_hunte",
        x: 64,
        y: 129,
        dir: 0,
        sprite: -1,
        name: "14-2",
        scope: :shared,
        trigger: {0, 0}
      },
      %{
        map: "job_hunte",
        x: 65,
        y: 128,
        dir: 0,
        sprite: -1,
        name: "14-3",
        scope: :shared,
        trigger: {0, 0}
      },
      %{
        map: "job_hunte",
        x: 65,
        y: 129,
        dir: 0,
        sprite: -1,
        name: "14-4",
        scope: :shared,
        trigger: {0, 0}
      },
      %{
        map: "job_hunte",
        x: 68,
        y: 126,
        dir: 0,
        sprite: -1,
        name: "15-1",
        scope: :shared,
        trigger: {0, 0}
      },
      %{
        map: "job_hunte",
        x: 68,
        y: 127,
        dir: 0,
        sprite: -1,
        name: "15-2",
        scope: :shared,
        trigger: {0, 0}
      },
      %{
        map: "job_hunte",
        x: 69,
        y: 126,
        dir: 0,
        sprite: -1,
        name: "15-3",
        scope: :shared,
        trigger: {0, 0}
      },
      %{
        map: "job_hunte",
        x: 69,
        y: 127,
        dir: 0,
        sprite: -1,
        name: "15-4",
        scope: :shared,
        trigger: {0, 0}
      },
      %{
        map: "job_hunte",
        x: 75,
        y: 128,
        dir: 0,
        sprite: -1,
        name: "16-1",
        scope: :shared,
        trigger: {1, 0}
      },
      %{
        map: "job_hunte",
        x: 75,
        y: 129,
        dir: 0,
        sprite: -1,
        name: "16-2",
        scope: :shared,
        trigger: {1, 0}
      },
      %{
        map: "job_hunte",
        x: 77,
        y: 128,
        dir: 0,
        sprite: -1,
        name: "16-3",
        scope: :shared,
        trigger: {0, 0}
      },
      %{
        map: "job_hunte",
        x: 77,
        y: 129,
        dir: 0,
        sprite: -1,
        name: "16-4",
        scope: :shared,
        trigger: {0, 0}
      },
      %{
        map: "job_hunte",
        x: 82,
        y: 126,
        dir: 0,
        sprite: -1,
        name: "17-1",
        scope: :shared,
        trigger: {0, 0}
      },
      %{
        map: "job_hunte",
        x: 82,
        y: 127,
        dir: 0,
        sprite: -1,
        name: "17-2",
        scope: :shared,
        trigger: {0, 0}
      },
      %{
        map: "job_hunte",
        x: 83,
        y: 126,
        dir: 0,
        sprite: -1,
        name: "17-3",
        scope: :shared,
        trigger: {0, 0}
      },
      %{
        map: "job_hunte",
        x: 83,
        y: 127,
        dir: 0,
        sprite: -1,
        name: "17-4",
        scope: :shared,
        trigger: {0, 0}
      },
      %{
        map: "job_hunte",
        x: 96,
        y: 128,
        dir: 0,
        sprite: -1,
        name: "18-1",
        scope: :shared,
        trigger: {0, 0}
      },
      %{
        map: "job_hunte",
        x: 96,
        y: 129,
        dir: 0,
        sprite: -1,
        name: "18-2",
        scope: :shared,
        trigger: {0, 0}
      },
      %{
        map: "job_hunte",
        x: 97,
        y: 128,
        dir: 0,
        sprite: -1,
        name: "18-3",
        scope: :shared,
        trigger: {0, 0}
      },
      %{
        map: "job_hunte",
        x: 97,
        y: 129,
        dir: 0,
        sprite: -1,
        name: "18-4",
        scope: :shared,
        trigger: {0, 0}
      },
      %{
        map: "job_hunte",
        x: 100,
        y: 126,
        dir: 0,
        sprite: -1,
        name: "19-1",
        scope: :shared,
        trigger: {0, 0}
      },
      %{
        map: "job_hunte",
        x: 100,
        y: 127,
        dir: 0,
        sprite: -1,
        name: "19-2",
        scope: :shared,
        trigger: {0, 0}
      },
      %{
        map: "job_hunte",
        x: 101,
        y: 126,
        dir: 0,
        sprite: -1,
        name: "19-3",
        scope: :shared,
        trigger: {0, 0}
      },
      %{
        map: "job_hunte",
        x: 101,
        y: 127,
        dir: 0,
        sprite: -1,
        name: "19-4",
        scope: :shared,
        trigger: {0, 0}
      },
      %{
        map: "job_hunte",
        x: 106,
        y: 128,
        dir: 0,
        sprite: -1,
        name: "20-1",
        scope: :shared,
        trigger: {0, 0}
      },
      %{
        map: "job_hunte",
        x: 106,
        y: 129,
        dir: 0,
        sprite: -1,
        name: "20-2",
        scope: :shared,
        trigger: {0, 0}
      },
      %{
        map: "job_hunte",
        x: 107,
        y: 128,
        dir: 0,
        sprite: -1,
        name: "20-3",
        scope: :shared,
        trigger: {0, 0}
      },
      %{
        map: "job_hunte",
        x: 107,
        y: 129,
        dir: 0,
        sprite: -1,
        name: "20-4",
        scope: :shared,
        trigger: {0, 0}
      },
      %{
        map: "job_hunte",
        x: 112,
        y: 126,
        dir: 0,
        sprite: -1,
        name: "21-1",
        scope: :shared,
        trigger: {0, 0}
      },
      %{
        map: "job_hunte",
        x: 112,
        y: 127,
        dir: 0,
        sprite: -1,
        name: "21-2",
        scope: :shared,
        trigger: {0, 0}
      },
      %{
        map: "job_hunte",
        x: 113,
        y: 126,
        dir: 0,
        sprite: -1,
        name: "21-3",
        scope: :shared,
        trigger: {0, 0}
      },
      %{
        map: "job_hunte",
        x: 113,
        y: 127,
        dir: 0,
        sprite: -1,
        name: "21-4",
        scope: :shared,
        trigger: {0, 0}
      },
      %{
        map: "job_hunte",
        x: 126,
        y: 126,
        dir: 0,
        sprite: -1,
        name: "22-1",
        scope: :shared,
        trigger: {0, 0}
      },
      %{
        map: "job_hunte",
        x: 126,
        y: 127,
        dir: 0,
        sprite: -1,
        name: "22-2",
        scope: :shared,
        trigger: {0, 0}
      },
      %{
        map: "job_hunte",
        x: 127,
        y: 126,
        dir: 0,
        sprite: -1,
        name: "22-3",
        scope: :shared,
        trigger: {0, 0}
      },
      %{
        map: "job_hunte",
        x: 127,
        y: 127,
        dir: 0,
        sprite: -1,
        name: "22-4",
        scope: :shared,
        trigger: {0, 0}
      },
      %{
        map: "job_hunte",
        x: 52,
        y: 122,
        dir: 0,
        sprite: -1,
        name: "23-1",
        scope: :shared,
        trigger: {0, 1}
      },
      %{
        map: "job_hunte",
        x: 52,
        y: 122,
        dir: 0,
        sprite: -1,
        name: "23-2",
        scope: :shared,
        trigger: {0, 1}
      },
      %{
        map: "job_hunte",
        x: 53,
        y: 120,
        dir: 0,
        sprite: -1,
        name: "23-3",
        scope: :shared,
        trigger: {1, 0}
      },
      %{
        map: "job_hunte",
        x: 54,
        y: 121,
        dir: 0,
        sprite: -1,
        name: "23-4",
        scope: :shared,
        trigger: {0, 0}
      },
      %{
        map: "job_hunte",
        x: 55,
        y: 121,
        dir: 0,
        sprite: -1,
        name: "23-5",
        scope: :shared,
        trigger: {0, 0}
      },
      %{
        map: "job_hunte",
        x: 55,
        y: 120,
        dir: 0,
        sprite: -1,
        name: "23-6",
        scope: :shared,
        trigger: {0, 0}
      },
      %{
        map: "job_hunte",
        x: 66,
        y: 120,
        dir: 0,
        sprite: -1,
        name: "24-1",
        scope: :shared,
        trigger: {0, 0}
      },
      %{
        map: "job_hunte",
        x: 66,
        y: 121,
        dir: 0,
        sprite: -1,
        name: "24-2",
        scope: :shared,
        trigger: {0, 0}
      },
      %{
        map: "job_hunte",
        x: 67,
        y: 120,
        dir: 0,
        sprite: -1,
        name: "24-3",
        scope: :shared,
        trigger: {0, 0}
      },
      %{
        map: "job_hunte",
        x: 67,
        y: 121,
        dir: 0,
        sprite: -1,
        name: "24-4",
        scope: :shared,
        trigger: {0, 0}
      },
      %{
        map: "job_hunte",
        x: 114,
        y: 118,
        dir: 0,
        sprite: -1,
        name: "25-1",
        scope: :shared,
        trigger: {0, 0}
      },
      %{
        map: "job_hunte",
        x: 114,
        y: 119,
        dir: 0,
        sprite: -1,
        name: "25-2",
        scope: :shared,
        trigger: {0, 0}
      },
      %{
        map: "job_hunte",
        x: 115,
        y: 118,
        dir: 0,
        sprite: -1,
        name: "25-3",
        scope: :shared,
        trigger: {0, 0}
      },
      %{
        map: "job_hunte",
        x: 115,
        y: 119,
        dir: 0,
        sprite: -1,
        name: "25-4",
        scope: :shared,
        trigger: {0, 0}
      },
      %{
        map: "job_hunte",
        x: 124,
        y: 120,
        dir: 0,
        sprite: -1,
        name: "26-1",
        scope: :shared,
        trigger: {0, 1}
      },
      %{
        map: "job_hunte",
        x: 125,
        y: 120,
        dir: 0,
        sprite: -1,
        name: "26-2",
        scope: :shared,
        trigger: {0, 1}
      },
      %{
        map: "job_hunte",
        x: 124,
        y: 118,
        dir: 0,
        sprite: -1,
        name: "26-3",
        scope: :shared,
        trigger: {0, 0}
      },
      %{
        map: "job_hunte",
        x: 125,
        y: 118,
        dir: 0,
        sprite: -1,
        name: "26-4",
        scope: :shared,
        trigger: {0, 0}
      },
      %{
        map: "job_hunte",
        x: 66,
        y: 116,
        dir: 0,
        sprite: -1,
        name: "27-1",
        scope: :shared,
        trigger: {0, 0}
      },
      %{
        map: "job_hunte",
        x: 66,
        y: 117,
        dir: 0,
        sprite: -1,
        name: "27-2",
        scope: :shared,
        trigger: {0, 0}
      },
      %{
        map: "job_hunte",
        x: 67,
        y: 116,
        dir: 0,
        sprite: -1,
        name: "27-3",
        scope: :shared,
        trigger: {0, 0}
      },
      %{
        map: "job_hunte",
        x: 67,
        y: 117,
        dir: 0,
        sprite: -1,
        name: "27-4",
        scope: :shared,
        trigger: {0, 0}
      },
      %{
        map: "job_hunte",
        x: 76,
        y: 114,
        dir: 0,
        sprite: -1,
        name: "28-1",
        scope: :shared,
        trigger: {0, 0}
      },
      %{
        map: "job_hunte",
        x: 76,
        y: 115,
        dir: 0,
        sprite: -1,
        name: "28-2",
        scope: :shared,
        trigger: {0, 0}
      },
      %{
        map: "job_hunte",
        x: 77,
        y: 114,
        dir: 0,
        sprite: -1,
        name: "28-3",
        scope: :shared,
        trigger: {0, 0}
      },
      %{
        map: "job_hunte",
        x: 77,
        y: 115,
        dir: 0,
        sprite: -1,
        name: "28-4",
        scope: :shared,
        trigger: {0, 0}
      },
      %{
        map: "job_hunte",
        x: 82,
        y: 116,
        dir: 0,
        sprite: -1,
        name: "29-1",
        scope: :shared,
        trigger: {0, 0}
      },
      %{
        map: "job_hunte",
        x: 82,
        y: 117,
        dir: 0,
        sprite: -1,
        name: "29-2",
        scope: :shared,
        trigger: {0, 0}
      },
      %{
        map: "job_hunte",
        x: 83,
        y: 116,
        dir: 0,
        sprite: -1,
        name: "29-3",
        scope: :shared,
        trigger: {0, 0}
      },
      %{
        map: "job_hunte",
        x: 83,
        y: 117,
        dir: 0,
        sprite: -1,
        name: "29-4",
        scope: :shared,
        trigger: {0, 0}
      },
      %{
        map: "job_hunte",
        x: 86,
        y: 114,
        dir: 0,
        sprite: -1,
        name: "30-1",
        scope: :shared,
        trigger: {0, 0}
      },
      %{
        map: "job_hunte",
        x: 86,
        y: 115,
        dir: 0,
        sprite: -1,
        name: "30-2",
        scope: :shared,
        trigger: {0, 0}
      },
      %{
        map: "job_hunte",
        x: 87,
        y: 114,
        dir: 0,
        sprite: -1,
        name: "30-3",
        scope: :shared,
        trigger: {0, 0}
      },
      %{
        map: "job_hunte",
        x: 87,
        y: 115,
        dir: 0,
        sprite: -1,
        name: "30-4",
        scope: :shared,
        trigger: {0, 0}
      },
      %{
        map: "job_hunte",
        x: 92,
        y: 115,
        dir: 0,
        sprite: -1,
        name: "31-1",
        scope: :shared,
        trigger: {1, 0}
      },
      %{
        map: "job_hunte",
        x: 92,
        y: 114,
        dir: 0,
        sprite: -1,
        name: "31-2",
        scope: :shared,
        trigger: {1, 0}
      },
      %{
        map: "job_hunte",
        x: 90,
        y: 115,
        dir: 0,
        sprite: -1,
        name: "31-3",
        scope: :shared,
        trigger: {0, 0}
      },
      %{
        map: "job_hunte",
        x: 102,
        y: 116,
        dir: 0,
        sprite: -1,
        name: "32-1",
        scope: :shared,
        trigger: {0, 0}
      },
      %{
        map: "job_hunte",
        x: 102,
        y: 117,
        dir: 0,
        sprite: -1,
        name: "32-2",
        scope: :shared,
        trigger: {0, 0}
      },
      %{
        map: "job_hunte",
        x: 103,
        y: 116,
        dir: 0,
        sprite: -1,
        name: "32-3",
        scope: :shared,
        trigger: {0, 0}
      },
      %{
        map: "job_hunte",
        x: 103,
        y: 117,
        dir: 0,
        sprite: -1,
        name: "32-4",
        scope: :shared,
        trigger: {0, 0}
      },
      %{
        map: "job_hunte",
        x: 114,
        y: 114,
        dir: 0,
        sprite: -1,
        name: "33-1",
        scope: :shared,
        trigger: {0, 0}
      },
      %{
        map: "job_hunte",
        x: 114,
        y: 115,
        dir: 0,
        sprite: -1,
        name: "33-2",
        scope: :shared,
        trigger: {0, 0}
      },
      %{
        map: "job_hunte",
        x: 115,
        y: 114,
        dir: 0,
        sprite: -1,
        name: "33-3",
        scope: :shared,
        trigger: {0, 0}
      },
      %{
        map: "job_hunte",
        x: 115,
        y: 115,
        dir: 0,
        sprite: -1,
        name: "33-4",
        scope: :shared,
        trigger: {0, 0}
      },
      %{
        map: "job_hunte",
        x: 54,
        y: 110,
        dir: 0,
        sprite: -1,
        name: "34-1",
        scope: :shared,
        trigger: {0, 1}
      },
      %{
        map: "job_hunte",
        x: 55,
        y: 110,
        dir: 0,
        sprite: -1,
        name: "34-2",
        scope: :shared,
        trigger: {0, 1}
      },
      %{
        map: "job_hunte",
        x: 54,
        y: 108,
        dir: 0,
        sprite: -1,
        name: "34-3",
        scope: :shared,
        trigger: {0, 0}
      },
      %{
        map: "job_hunte",
        x: 55,
        y: 108,
        dir: 0,
        sprite: -1,
        name: "34-4",
        scope: :shared,
        trigger: {0, 0}
      },
      %{
        map: "job_hunte",
        x: 64,
        y: 112,
        dir: 0,
        sprite: -1,
        name: "35-1",
        scope: :shared,
        trigger: {0, 0}
      },
      %{
        map: "job_hunte",
        x: 64,
        y: 113,
        dir: 0,
        sprite: -1,
        name: "35-2",
        scope: :shared,
        trigger: {0, 0}
      },
      %{
        map: "job_hunte",
        x: 65,
        y: 112,
        dir: 0,
        sprite: -1,
        name: "35-3",
        scope: :shared,
        trigger: {0, 0}
      },
      %{
        map: "job_hunte",
        x: 65,
        y: 113,
        dir: 0,
        sprite: -1,
        name: "35-4",
        scope: :shared,
        trigger: {0, 0}
      },
      %{
        map: "job_hunte",
        x: 80,
        y: 110,
        dir: 0,
        sprite: -1,
        name: "36-1",
        scope: :shared,
        trigger: {0, 0}
      },
      %{
        map: "job_hunte",
        x: 80,
        y: 111,
        dir: 0,
        sprite: -1,
        name: "36-2",
        scope: :shared,
        trigger: {0, 0}
      },
      %{
        map: "job_hunte",
        x: 81,
        y: 110,
        dir: 0,
        sprite: -1,
        name: "36-3",
        scope: :shared,
        trigger: {0, 0}
      },
      %{
        map: "job_hunte",
        x: 81,
        y: 111,
        dir: 0,
        sprite: -1,
        name: "36-4",
        scope: :shared,
        trigger: {0, 0}
      },
      %{
        map: "job_hunte",
        x: 90,
        y: 108,
        dir: 0,
        sprite: -1,
        name: "37-1",
        scope: :shared,
        trigger: {0, 6}
      },
      %{
        map: "job_hunte",
        x: 91,
        y: 108,
        dir: 0,
        sprite: -1,
        name: "37-2",
        scope: :shared,
        trigger: {0, 5}
      },
      %{
        map: "job_hunte",
        x: 91,
        y: 102,
        dir: 0,
        sprite: -1,
        name: "37-3",
        scope: :shared,
        trigger: {0, 0}
      },
      %{
        map: "job_hunte",
        x: 98,
        y: 109,
        dir: 0,
        sprite: -1,
        name: "38-1",
        scope: :shared,
        trigger: {0, 2}
      },
      %{
        map: "job_hunte",
        x: 99,
        y: 109,
        dir: 0,
        sprite: -1,
        name: "38-2",
        scope: :shared,
        trigger: {0, 2}
      },
      %{
        map: "job_hunte",
        x: 103,
        y: 109,
        dir: 0,
        sprite: -1,
        name: "38-3",
        scope: :shared,
        trigger: {3, 0}
      },
      %{
        map: "job_hunte",
        x: 103,
        y: 108,
        dir: 0,
        sprite: -1,
        name: "38-4",
        scope: :shared,
        trigger: {3, 0}
      },
      %{
        map: "job_hunte",
        x: 97,
        y: 106,
        dir: 0,
        sprite: -1,
        name: "39-1",
        scope: :shared,
        trigger: {2, 0}
      },
      %{
        map: "job_hunte",
        x: 96,
        y: 107,
        dir: 0,
        sprite: -1,
        name: "39-2",
        scope: :shared,
        trigger: {1, 0}
      },
      %{
        map: "job_hunte",
        x: 94,
        y: 108,
        dir: 0,
        sprite: -1,
        name: "39-3",
        scope: :shared,
        trigger: {0, 1}
      },
      %{
        map: "job_hunte",
        x: 95,
        y: 109,
        dir: 0,
        sprite: -1,
        name: "39-4",
        scope: :shared,
        trigger: {0, 0}
      },
      %{
        map: "job_hunte",
        x: 95,
        y: 108,
        dir: 0,
        sprite: -1,
        name: "40-1",
        scope: :shared,
        trigger: {0, 0}
      },
      %{
        map: "job_hunte",
        x: 94,
        y: 106,
        dir: 0,
        sprite: -1,
        name: "40-2",
        scope: :shared,
        trigger: {0, 0}
      },
      %{
        map: "job_hunte",
        x: 96,
        y: 102,
        dir: 0,
        sprite: -1,
        name: "40-3",
        scope: :shared,
        trigger: {0, 3}
      },
      %{
        map: "job_hunte",
        x: 97,
        y: 102,
        dir: 0,
        sprite: -1,
        name: "40-4",
        scope: :shared,
        trigger: {0, 3}
      },
      %{
        map: "job_hunte",
        x: 95,
        y: 98,
        dir: 0,
        sprite: -1,
        name: "41-1",
        scope: :shared,
        trigger: {2, 0}
      },
      %{
        map: "job_hunte",
        x: 94,
        y: 99,
        dir: 0,
        sprite: -1,
        name: "42-1",
        scope: :shared,
        trigger: {1, 0}
      },
      %{
        map: "job_hunte",
        x: 92,
        y: 98,
        dir: 0,
        sprite: -1,
        name: "43-1",
        scope: :shared,
        trigger: {0, 0}
      },
      %{
        map: "job_hunte",
        x: 112,
        y: 110,
        dir: 0,
        sprite: -1,
        name: "44-1",
        scope: :shared,
        trigger: {0, 0}
      },
      %{
        map: "job_hunte",
        x: 112,
        y: 111,
        dir: 0,
        sprite: -1,
        name: "44-2",
        scope: :shared,
        trigger: {0, 0}
      },
      %{
        map: "job_hunte",
        x: 113,
        y: 110,
        dir: 0,
        sprite: -1,
        name: "44-3",
        scope: :shared,
        trigger: {0, 0}
      },
      %{
        map: "job_hunte",
        x: 113,
        y: 111,
        dir: 0,
        sprite: -1,
        name: "44-4",
        scope: :shared,
        trigger: {0, 0}
      },
      %{
        map: "job_hunte",
        x: 126,
        y: 108,
        dir: 0,
        sprite: -1,
        name: "45-1",
        scope: :shared,
        trigger: {0, 1}
      },
      %{
        map: "job_hunte",
        x: 127,
        y: 108,
        dir: 0,
        sprite: -1,
        name: "45-2",
        scope: :shared,
        trigger: {0, 1}
      },
      %{
        map: "job_hunte",
        x: 126,
        y: 106,
        dir: 0,
        sprite: -1,
        name: "45-3",
        scope: :shared,
        trigger: {0, 0}
      },
      %{
        map: "job_hunte",
        x: 126,
        y: 106,
        dir: 0,
        sprite: -1,
        name: "45-4",
        scope: :shared,
        trigger: {0, 0}
      },
      %{
        map: "job_hunte",
        x: 53,
        y: 102,
        dir: 0,
        sprite: -1,
        name: "46-1",
        scope: :shared,
        trigger: {1, 1}
      },
      %{
        map: "job_hunte",
        x: 55,
        y: 102,
        dir: 0,
        sprite: -1,
        name: "46-2",
        scope: :shared,
        trigger: {0, 1}
      },
      %{
        map: "job_hunte",
        x: 53,
        y: 100,
        dir: 0,
        sprite: -1,
        name: "46-3",
        scope: :shared,
        trigger: {1, 0}
      },
      %{
        map: "job_hunte",
        x: 55,
        y: 100,
        dir: 0,
        sprite: -1,
        name: "46-4",
        scope: :shared,
        trigger: {0, 0}
      },
      %{
        map: "job_hunte",
        x: 64,
        y: 106,
        dir: 0,
        sprite: -1,
        name: "47-1",
        scope: :shared,
        trigger: {0, 0}
      },
      %{
        map: "job_hunte",
        x: 64,
        y: 107,
        dir: 0,
        sprite: -1,
        name: "47-2",
        scope: :shared,
        trigger: {0, 0}
      },
      %{
        map: "job_hunte",
        x: 65,
        y: 106,
        dir: 0,
        sprite: -1,
        name: "47-3",
        scope: :shared,
        trigger: {0, 0}
      },
      %{
        map: "job_hunte",
        x: 65,
        y: 107,
        dir: 0,
        sprite: -1,
        name: "47-4",
        scope: :shared,
        trigger: {0, 0}
      },
      %{
        map: "job_hunte",
        x: 66,
        y: 100,
        dir: 0,
        sprite: -1,
        name: "48-1",
        scope: :shared,
        trigger: {0, 0}
      },
      %{
        map: "job_hunte",
        x: 66,
        y: 101,
        dir: 0,
        sprite: -1,
        name: "48-2",
        scope: :shared,
        trigger: {0, 0}
      },
      %{
        map: "job_hunte",
        x: 67,
        y: 100,
        dir: 0,
        sprite: -1,
        name: "48-3",
        scope: :shared,
        trigger: {0, 0}
      },
      %{
        map: "job_hunte",
        x: 67,
        y: 101,
        dir: 0,
        sprite: -1,
        name: "48-4",
        scope: :shared,
        trigger: {0, 0}
      },
      %{
        map: "job_hunte",
        x: 86,
        y: 106,
        dir: 0,
        sprite: -1,
        name: "49-1",
        scope: :shared,
        trigger: {0, 1}
      },
      %{
        map: "job_hunte",
        x: 87,
        y: 106,
        dir: 0,
        sprite: -1,
        name: "49-2",
        scope: :shared,
        trigger: {0, 1}
      },
      %{
        map: "job_hunte",
        x: 82,
        y: 104,
        dir: 0,
        sprite: -1,
        name: "49-3",
        scope: :shared,
        trigger: {5, 0}
      },
      %{
        map: "job_hunte",
        x: 81,
        y: 105,
        dir: 0,
        sprite: -1,
        name: "49-4",
        scope: :shared,
        trigger: {4, 0}
      },
      %{
        map: "job_hunte",
        x: 76,
        y: 105,
        dir: 0,
        sprite: -1,
        name: "50-1",
        scope: :shared,
        trigger: {0, 0}
      },
      %{
        map: "job_hunte",
        x: 76,
        y: 104,
        dir: 0,
        sprite: -1,
        name: "50-2",
        scope: :shared,
        trigger: {0, 0}
      },
      %{
        map: "job_hunte",
        x: 78,
        y: 101,
        dir: 0,
        sprite: -1,
        name: "50-3",
        scope: :shared,
        trigger: {0, 2}
      },
      %{
        map: "job_hunte",
        x: 79,
        y: 101,
        dir: 0,
        sprite: -1,
        name: "50-4",
        scope: :shared,
        trigger: {0, 2}
      },
      %{
        map: "job_hunte",
        x: 76,
        y: 99,
        dir: 0,
        sprite: -1,
        name: "51-1",
        scope: :shared,
        trigger: {1, 0}
      },
      %{
        map: "job_hunte",
        x: 77,
        y: 98,
        dir: 0,
        sprite: -1,
        name: "51-2",
        scope: :shared,
        trigger: {2, 0}
      },
      %{
        map: "job_hunte",
        x: 74,
        y: 99,
        dir: 0,
        sprite: -1,
        name: "51-3",
        scope: :shared,
        trigger: {0, 0}
      },
      %{
        map: "job_hunte",
        x: 74,
        y: 98,
        dir: 0,
        sprite: -1,
        name: "51-4",
        scope: :shared,
        trigger: {0, 0}
      },
      %{
        map: "job_hunte",
        x: 82,
        y: 100,
        dir: 0,
        sprite: -1,
        name: "53-1",
        scope: :shared,
        trigger: {0, 0}
      },
      %{
        map: "job_hunte",
        x: 82,
        y: 101,
        dir: 0,
        sprite: -1,
        name: "53-2",
        scope: :shared,
        trigger: {0, 0}
      },
      %{
        map: "job_hunte",
        x: 83,
        y: 100,
        dir: 0,
        sprite: -1,
        name: "53-3",
        scope: :shared,
        trigger: {0, 0}
      },
      %{
        map: "job_hunte",
        x: 83,
        y: 101,
        dir: 0,
        sprite: -1,
        name: "53-4",
        scope: :shared,
        trigger: {0, 0}
      },
      %{
        map: "job_hunte",
        x: 106,
        y: 104,
        dir: 0,
        sprite: -1,
        name: "54-1",
        scope: :shared,
        trigger: {0, 0}
      },
      %{
        map: "job_hunte",
        x: 106,
        y: 105,
        dir: 0,
        sprite: -1,
        name: "54-2",
        scope: :shared,
        trigger: {0, 0}
      },
      %{
        map: "job_hunte",
        x: 107,
        y: 104,
        dir: 0,
        sprite: -1,
        name: "54-3",
        scope: :shared,
        trigger: {0, 0}
      },
      %{
        map: "job_hunte",
        x: 107,
        y: 105,
        dir: 0,
        sprite: -1,
        name: "54-4",
        scope: :shared,
        trigger: {0, 0}
      },
      %{
        map: "job_hunte",
        x: 112,
        y: 104,
        dir: 0,
        sprite: -1,
        name: "55-1",
        scope: :shared,
        trigger: {0, 1}
      },
      %{
        map: "job_hunte",
        x: 113,
        y: 104,
        dir: 0,
        sprite: -1,
        name: "55-2",
        scope: :shared,
        trigger: {0, 1}
      },
      %{
        map: "job_hunte",
        x: 112,
        y: 102,
        dir: 0,
        sprite: -1,
        name: "55-3",
        scope: :shared,
        trigger: {0, 0}
      },
      %{
        map: "job_hunte",
        x: 113,
        y: 102,
        dir: 0,
        sprite: -1,
        name: "55-4",
        scope: :shared,
        trigger: {0, 0}
      },
      %{
        map: "job_hunte",
        x: 54,
        y: 92,
        dir: 0,
        sprite: -1,
        name: "56-1",
        scope: :shared,
        trigger: {0, 0}
      },
      %{
        map: "job_hunte",
        x: 54,
        y: 93,
        dir: 0,
        sprite: -1,
        name: "56-2",
        scope: :shared,
        trigger: {0, 0}
      },
      %{
        map: "job_hunte",
        x: 55,
        y: 92,
        dir: 0,
        sprite: -1,
        name: "56-3",
        scope: :shared,
        trigger: {0, 0}
      },
      %{
        map: "job_hunte",
        x: 55,
        y: 93,
        dir: 0,
        sprite: -1,
        name: "56-4",
        scope: :shared,
        trigger: {0, 0}
      },
      %{
        map: "job_hunte",
        x: 52,
        y: 90,
        dir: 0,
        sprite: -1,
        name: "56-5",
        scope: :shared,
        trigger: {0, 0}
      },
      %{
        map: "job_hunte",
        x: 52,
        y: 91,
        dir: 0,
        sprite: -1,
        name: "56-6",
        scope: :shared,
        trigger: {0, 0}
      },
      %{
        map: "job_hunte",
        x: 53,
        y: 90,
        dir: 0,
        sprite: -1,
        name: "56-7",
        scope: :shared,
        trigger: {0, 0}
      },
      %{
        map: "job_hunte",
        x: 53,
        y: 91,
        dir: 0,
        sprite: -1,
        name: "56-8",
        scope: :shared,
        trigger: {0, 0}
      },
      %{
        map: "job_hunte",
        x: 64,
        y: 92,
        dir: 0,
        sprite: -1,
        name: "57-1",
        scope: :shared,
        trigger: {0, 0}
      },
      %{
        map: "job_hunte",
        x: 64,
        y: 93,
        dir: 0,
        sprite: -1,
        name: "57-2",
        scope: :shared,
        trigger: {0, 0}
      },
      %{
        map: "job_hunte",
        x: 65,
        y: 92,
        dir: 0,
        sprite: -1,
        name: "57-3",
        scope: :shared,
        trigger: {0, 0}
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @announcements %{
    2 => {"", ", yes you! Go back and start over!"},
    3 => {"", " has failed!...well...you will if you don't start over..."},
    4 => {"", ", has failed me! Go back to where you started!"},
    5 => {"", ", you have blundered into a trap. I'm sorry, but for now, YOU LOSE."},
    6 => {"", ", what are you doing!? Go back and do it again!"},
    7 => {"", ", come on! You can do better than this!! Try again!"},
    8 => {"", ", has fallen into a trap...again. But don't worry, you're getting better."},
    9 => {"", ", fail, fail, fail... Go back to where you started!"},
    10 => {"", "... aww~ Try again! You can do it!"},
    11 => {"", ", @#$%#^!@ and you wanna be a what? Hunter? Get back there!"},
    12 => {"", " was defeated by the forces of evil. Don't give up, hero!"},
    13 => {"I put a spell on you ", " and now you're mine! Go start over now."},
    14 =>
      {"",
       ". G'day mate, welcome to the land down under. As a present, I'll send you to the starting point..."},
    15 => {"That's my nest ", "! dont step there, squawk~ Start over."},
    16 => {"", ", another archer down. 3 more to go!"},
    17 => {"", ", have you got what it takes? Then try again."},
    18 =>
      {"Alas, ",
       ", you have fallen prey to the most feared of traps. The dreaded stink bomb! Run run run awaaaaaay!"},
    19 => {"", " had too much prune juice to drink today. Back to the starting point~"},
    20 =>
      {"No.... ", ", you have fallen into a trap. You will be returned to the starting point."},
    21 =>
      {"Meow *pounce* look my kitties we'll have some",
       "stew. Back to the starting point if you don't want to become stew!"},
    22 =>
      {"Sorry ",
       ", but you've actually found a BAD secret. You will be returned to the starting point."},
    23 =>
      {"", ", silly Archer...your tenacity is touching. But it's back to the start for you..."},
    24 =>
      {"", ", you've fallen and you can't get up. You'll be carried back to the starting point."},
    25 => {"Skip a turn ", ", go back to start."},
    26 => {"", ", nya nya, heh heh heh. You will be returned to the starting point."},
    27 => {"Practice is over ", ". This time show me for real."},
    28 =>
      {"",
       ", this is a Poring jellopy raid...Get out! Start from the beginning if you wish to continue."},
    29 => {"Disconnected from server. ", ", you have to start over."},
    30 => {"", ", what does this button do...oops! I'm afraid you have to start over."},
    31 =>
      {"",
       ", you have entered the bonus round! Aaaand, you lost. You will be returned to the starting point."},
    32 =>
      {"Oh, no ",
       ", you've stepped on a hive of bees. You narrowly escaped, all the way back to the beginning."},
    33 => {"", ", wait wait. That's a trap! Oh wait, that's dog. . . ."},
    34 => {"Stop ", "! For stepping on that trap, I shall punish you!"},
    35 => {"", ", I'll be back. . . I hope you will too."},
    36 => {"", ", Come with me if you want to live. . to the starting point."},
    37 => {"", ", my... precious! Go back to the starting point."},
    38 =>
      {"Follow the yellow brick road... No wait, ",
       "!! Not that way...Back to the starting point it is."},
    39 =>
      {"",
       ", you've really go to get the hang of this 'in tune with nature' thing. Now, you're lost!"},
    40 => {"", ", it's only a story...not real. But you will be returned to the starting point."},
    41 =>
      {"",
       ", you have fallen into a trap. And the trap...has fallen into you. Returning you to the starting point."},
    42 =>
      {"Fear not ",
       ", for you too, shall learn the powers of the dark side. You will now be returned to the starting point."},
    43 =>
      {"",
       ", fell into a trap. Quite easily too, I'm afraid. But this hero won't be beaten that easily!"},
    46 => {"Oy oy, ", ".. I've seen blind Porings get further! Go back to the starting point."},
    47 =>
      {"MY EYES!! ",
       ", you... you.. stepped on them. Go try again...I'd cry for you if I could even shed tears..."},
    48 =>
      {"", ", where are you? Right...NOT at the place where'd you be if you passed the test."},
    49 =>
      {" Wow, they actually paid a guy to think of these comments. ",
       ", you can go back to the starting point."},
    50 =>
      {" My word, ",
       "! You've precariously fallen into a trap! You will be returned back to the start. Cheerio~!"},
    51 => {"", ", do you have any idea where you're going? Start over *sigh*."},
    52 => {"", ", do you like green tea ice cream? No? Go back to the starting point...*hmph*"},
    53 => {"Oh, no.. ", ", are you hurt? Come now, let's go back to the starting point."},
    54 => {"Hi ", ", how are you? Here's a present~ a free warp! Back to the starting point."},
    55 =>
      {"",
       ".......... did you know that that was a trap? I hope so, otherwise, I guess you'd be pretty embarassed."},
    56 =>
      {"",
       ", what do you think of the interior design? I worked very hard on it... and this lovely feature that sends you back to the starting point."},
    57 =>
      {"BOOM BAM BOOM! ",
       ", you have fallen into my trap! But I won't kill you...just...humiliate you..."},
    58 => {"Oh, ", ".. You can do better. Try again!"},
    59 =>
      {"Hello, this is your local Kafra worker... ",
       ", your mommy is waiting for you at the checkout line."},
    60 =>
      {"",
       ", if you do well. I'll have a nice present waiting for you... What is it? You'll see if you pass~ Go try again now!"},
    61 =>
      {"",
       " faaaaaaaaaaaaaaaaailed.. Hehe, just kidding. You will be returned to the starting point so try again!"},
    62 =>
      {"",
       ", you fell into a trap. You should watch your feet more. What? Invisible? That's baby talk! Now go try again!"},
    63 =>
      {" Sorry, ",
       ", you have fallen into a trap. But I'll be nice and send you to the starting point."},
    64 => {"", ", HAHAHAHAHAHA!!!! I can't believe you fell for that one!"},
    65 => {"", ", I was just about to tell you about that one...but, I didn't? Back to start."},
    66 =>
      {"",
       "...I'm sorry my friend, but you lose. But don't worry, its not like this message is broadcast or anything."},
    67 =>
      {"", ", I'm not so sure that you qualify for this anymore... Try again and prove me wrong."},
    68 => {"", ", OW...now that's gotta hurt. Back to the start~"},
    69 => {"", ", I find your lack of faith disturbing... Let's start over."},
    70 =>
      {"",
       ", your eyes can deceive you. Don't trust them. Stretch out with your feelings. Try again now."},
    71 =>
      {"",
       ", if you once start down the dark path, forever it will dominate your destiny. You shall be returned to the starting point."},
    72 =>
      {"",
       ", size doesn't matter. But, the number of traps that caught you do. Try again and win this time!"},
    73 => {"", ", try not. Do or do not. There is no try."},
    74 => {"", ", that is why you fail. Now try again!"},
    75 =>
      {"",
       ", look. If its made of metal and looks like it has teeth, you shouldn't put your foot in it. So simple, really..."},
    76 => {"", ", you are beaten. It is useless to resist."},
    77 =>
      {"", ", I'm looking forward to completing your training. In time you will call me Master."},
    78 => {"", ", your overconfidence is your weakness."},
    79 => {"", ", watch your step. This place can be a little rough."},
    80 => {"", ", oh I told you it was dangerous here."},
    81 => {"", ", everything is proceeding as I have foreseen."},
    82 => {"", ", you should have not come back."},
    83 =>
      {"", ", there are alternatives to fighting. But not to losing to this test. Now try again!"},
    84 =>
      {"", ", now that's a name I haven't heard in a while...let's hope I don't hear it again~!"},
    85 => {"", ", we do not train to be merciful here, mercy is for the weak!"},
    86 => {"", ", defeat does not exist here, does it?!"},
    87 => {"", ", concentrate. Focus your powers!"},
    88 => {"", ", am I going mad, or did the word -think- escape your lips?"},
    89 => {"", ", you're just stalling now."},
    90 => {"", ", life isn't always fair."},
    91 => {"", ".... Uhhh...it's not OUR fault...."},
    92 => {"", ", survivability takes priority."},
    93 => {"", ", people have the strength to overcome their obstacles...everyone can."},
    94 =>
      {"",
       ", there is happiness for those who accept their fate, and there is glory for those who resist their fate."},
    95 =>
      {"", ", some things are real and some things are false. Can't you tell the difference?"},
    96 =>
      {"",
       ", we are having fun aren't we? Everyday here is like a dream. I really hope it's going to be like this forever."},
    97 => {"", ", I'll give you just one piece of advice... dying hurts like hell."},
    98 => {"", ", don't give up the ghost! Just be more careful..."},
    99 =>
      {"", ", death is a gift given at birth. But...these traps won't kill you, don't worry."},
    100 =>
      {"",
       ", I was counting on you from the beginning. But I guess you're gonna make me wait longer..."},
    101 =>
      {"",
       ", always with the end comes hope and rebirth. But it's back to the beginning for you~"},
    102 =>
      {"",
       ", have I ever told you about the power held in a single tear? Its okay to shed one now, I know its hard..."},
    103 =>
      {"",
       ", happiness often sneaks in through a door you didn't know you left open. Sort of like...hidden traps!"},
    104 => {"", ", ....Chii?"},
    105 => {"", ", Mine! Mine! Mine! Mine!"},
    106 => {"", ", it's time to duel!"},
    107 => {"", ", I choose you!...wait... uagh...not you!..."},
    108 => {"", ", this isn't the time to be complimenting it!"},
    109 => {"", "...Oh great, what else could go wrong today?"},
    110 =>
      {"", ", don't worry, I always keep a spare. We're not running out of traps anytime soon..."},
    111 =>
      {"",
       ", when bad things happen, don't give up. The day will come when you will look back and laugh at them. But not today."},
    112 => {"", ", don't worry about it. We're good at fighting losing battles, remember?"},
    113 =>
      {"",
       ", you remember how it was like when you felt really slick? That feeling won't come back for a while..."},
    114 => {"", ", you must forget about your past for the sake of your own happiness."},
    115 => {"", ", if you can fool your friends, you can fool your enemies."},
    116 => {"", ", this world is made up of love and peace!"},
    117 => {"", ", if you fail, you must drink this.....*evil grin*"},
    118 => {"", ", don't say we didn't warn you!"},
    119 =>
      {"",
       ", curiosity killed the cat. Lucky for me I'm not a cat. Oh, and um, you too of course."},
    120 => {"", ", STUDY!STUDY!STUDY!STUDY!STUDY!STUDY!STUDY!STUDY!STUDY!STUDY!"},
    121 => {"", ", how you like me now? That's right, that was MY trap!"},
    122 =>
      {"",
       "...brilliant...just absolutely...genius. Sorry, I was talking about all these crazy traps."},
    123 => {"", ", it's time to bust out of that trap, Houdini-style! Hey, wait...come back!"},
    124 =>
      {"",
       ", it looks like you could really be in trouble this time...no worries, just try this again!"},
    125 => {"", "...not smooth, dude. Go for it again, one more time!"},
    126 => {"", ",it looks like you could really be in a pickle. Back to the starting point..."},
    127 =>
      {"",
       ", just think of it as Karma. Someday, you'll be setting hundreds of traps of your own..."},
    128 =>
      {"", ", bad news dude...its another trap. You'll get the hang of this, I believe in you!"},
    129 => {"", ", don't give up! The world still needs you!"},
    130 => {"", ", it's okay to cry. Just not too loudly."},
    131 =>
      {"",
       "...oh man. It's tiring setting up all these traps. You guys have got to stop falling into them!"}
  }

  @default_announcement {"",
                         ", you have fallen into a trap. You will be returned to the starting point."}

  @impl true
  @spec on_event(String.t(), Ctx.t()) :: Ctx.t()
  def on_event("OnTouch_", ctx) do
    ctx
    |> mapannounce("job_hunte", announcement(:rand.uniform(200) - 1, ctx), 1)
    |> set_char_var(:HNTR_Q, 13)
    |> warp("job_hunte", 176, 22)
    |> donpcevent("Manager#hnt::OnReset")
    |> donpcevent("Waiting Room#hnt::OnStart")
  end

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  # rAthena starts a click at the first label, so it runs this body too.
  def on_talk(ctx), do: on_event("OnTouch_", ctx)

  defp announcement(44, _ctx) do
    " Tip of the day: Do not step on the traps. You will be returned to the starting point."
  end

  defp announcement(45, ctx) do
    name = char_name(ctx, 0)
    "#{name} fell into a trap. Once again, for clarity's sake, the name is #{name}."
  end

  defp announcement(roll, ctx) do
    {prefix, suffix} = Map.get(@announcements, roll, @default_announcement)
    "#{prefix}#{char_name(ctx, 0)}#{suffix}"
  end
end
