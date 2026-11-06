defmodule Aesir.ZoneServer.Content.Npc.Jobs.M21.Hunter.M574Hnttrap2 do
  @moduledoc """
  Hunter test trap that sends a careless examinee back to the starting point.

  ## Behavior

  - Broadcasts that the examinee has failed.
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
        x: 65,
        y: 93,
        dir: 0,
        sprite: -1,
        name: "57-4::HntTrap2",
        scope: :shared,
        unique_name: "HntTrap2"
      },
      %{
        map: "job_hunte",
        x: 76,
        y: 94,
        dir: 0,
        sprite: -1,
        name: "58-1",
        scope: :shared,
        trigger: {0, 0}
      },
      %{
        map: "job_hunte",
        x: 76,
        y: 95,
        dir: 0,
        sprite: -1,
        name: "58-2",
        scope: :shared,
        trigger: {0, 0}
      },
      %{
        map: "job_hunte",
        x: 77,
        y: 94,
        dir: 0,
        sprite: -1,
        name: "58-3",
        scope: :shared,
        trigger: {0, 0}
      },
      %{
        map: "job_hunte",
        x: 77,
        y: 95,
        dir: 0,
        sprite: -1,
        name: "58-4",
        scope: :shared,
        trigger: {0, 0}
      },
      %{
        map: "job_hunte",
        x: 78,
        y: 92,
        dir: 0,
        sprite: -1,
        name: "59-1",
        scope: :shared,
        trigger: {0, 0}
      },
      %{
        map: "job_hunte",
        x: 78,
        y: 93,
        dir: 0,
        sprite: -1,
        name: "59-2",
        scope: :shared,
        trigger: {0, 0}
      },
      %{
        map: "job_hunte",
        x: 79,
        y: 92,
        dir: 0,
        sprite: -1,
        name: "59-3",
        scope: :shared,
        trigger: {0, 0}
      },
      %{
        map: "job_hunte",
        x: 79,
        y: 93,
        dir: 0,
        sprite: -1,
        name: "59-4",
        scope: :shared,
        trigger: {0, 0}
      },
      %{
        map: "job_hunte",
        x: 86,
        y: 92,
        dir: 0,
        sprite: -1,
        name: "60-1",
        scope: :shared,
        trigger: {0, 0}
      },
      %{
        map: "job_hunte",
        x: 86,
        y: 93,
        dir: 0,
        sprite: -1,
        name: "60-2",
        scope: :shared,
        trigger: {0, 0}
      },
      %{
        map: "job_hunte",
        x: 87,
        y: 92,
        dir: 0,
        sprite: -1,
        name: "60-3",
        scope: :shared,
        trigger: {0, 0}
      },
      %{
        map: "job_hunte",
        x: 87,
        y: 93,
        dir: 0,
        sprite: -1,
        name: "60-4",
        scope: :shared,
        trigger: {0, 0}
      },
      %{
        map: "job_hunte",
        x: 90,
        y: 96,
        dir: 0,
        sprite: -1,
        name: "61-1",
        scope: :shared,
        trigger: {0, 0}
      },
      %{
        map: "job_hunte",
        x: 90,
        y: 97,
        dir: 0,
        sprite: -1,
        name: "61-2",
        scope: :shared,
        trigger: {0, 0}
      },
      %{
        map: "job_hunte",
        x: 91,
        y: 96,
        dir: 0,
        sprite: -1,
        name: "61-3",
        scope: :shared,
        trigger: {0, 0}
      },
      %{
        map: "job_hunte",
        x: 91,
        y: 97,
        dir: 0,
        sprite: -1,
        name: "61-4",
        scope: :shared,
        trigger: {0, 0}
      },
      %{
        map: "job_hunte",
        x: 99,
        y: 95,
        dir: 0,
        sprite: -1,
        name: "62-1",
        scope: :shared,
        trigger: {1, 0}
      },
      %{
        map: "job_hunte",
        x: 99,
        y: 94,
        dir: 0,
        sprite: -1,
        name: "62-2",
        scope: :shared,
        trigger: {1, 0}
      },
      %{
        map: "job_hunte",
        x: 101,
        y: 94,
        dir: 0,
        sprite: -1,
        name: "62-3",
        scope: :shared,
        trigger: {0, 1}
      },
      %{
        map: "job_hunte",
        x: 100,
        y: 93,
        dir: 0,
        sprite: -1,
        name: "62-4",
        scope: :shared,
        trigger: {0, 0}
      },
      %{
        map: "job_hunte",
        x: 100,
        y: 92,
        dir: 0,
        sprite: -1,
        name: "63-1",
        scope: :shared,
        trigger: {0, 0}
      },
      %{
        map: "job_hunte",
        x: 101,
        y: 92,
        dir: 0,
        sprite: -1,
        name: "63-2",
        scope: :shared,
        trigger: {0, 0}
      },
      %{
        map: "job_hunte",
        x: 102,
        y: 98,
        dir: 0,
        sprite: -1,
        name: "64-1",
        scope: :shared,
        trigger: {0, 0}
      },
      %{
        map: "job_hunte",
        x: 102,
        y: 99,
        dir: 0,
        sprite: -1,
        name: "64-2",
        scope: :shared,
        trigger: {0, 0}
      },
      %{
        map: "job_hunte",
        x: 103,
        y: 98,
        dir: 0,
        sprite: -1,
        name: "64-3",
        scope: :shared,
        trigger: {0, 0}
      },
      %{
        map: "job_hunte",
        x: 103,
        y: 99,
        dir: 0,
        sprite: -1,
        name: "64-4",
        scope: :shared,
        trigger: {0, 0}
      },
      %{
        map: "job_hunte",
        x: 102,
        y: 90,
        dir: 0,
        sprite: -1,
        name: "65-1",
        scope: :shared,
        trigger: {0, 0}
      },
      %{
        map: "job_hunte",
        x: 102,
        y: 91,
        dir: 0,
        sprite: -1,
        name: "65-2",
        scope: :shared,
        trigger: {0, 0}
      },
      %{
        map: "job_hunte",
        x: 103,
        y: 90,
        dir: 0,
        sprite: -1,
        name: "65-3",
        scope: :shared,
        trigger: {0, 0}
      },
      %{
        map: "job_hunte",
        x: 103,
        y: 91,
        dir: 0,
        sprite: -1,
        name: "65-4",
        scope: :shared,
        trigger: {0, 0}
      },
      %{
        map: "job_hunte",
        x: 114,
        y: 96,
        dir: 0,
        sprite: -1,
        name: "66-1",
        scope: :shared,
        trigger: {0, 0}
      },
      %{
        map: "job_hunte",
        x: 114,
        y: 97,
        dir: 0,
        sprite: -1,
        name: "66-2",
        scope: :shared,
        trigger: {0, 0}
      },
      %{
        map: "job_hunte",
        x: 115,
        y: 96,
        dir: 0,
        sprite: -1,
        name: "66-3",
        scope: :shared,
        trigger: {0, 0}
      },
      %{
        map: "job_hunte",
        x: 115,
        y: 97,
        dir: 0,
        sprite: -1,
        name: "66-4",
        scope: :shared,
        trigger: {0, 0}
      },
      %{
        map: "job_hunte",
        x: 112,
        y: 90,
        dir: 0,
        sprite: -1,
        name: "67-1",
        scope: :shared,
        trigger: {0, 0}
      },
      %{
        map: "job_hunte",
        x: 112,
        y: 91,
        dir: 0,
        sprite: -1,
        name: "67-2",
        scope: :shared,
        trigger: {0, 0}
      },
      %{
        map: "job_hunte",
        x: 113,
        y: 90,
        dir: 0,
        sprite: -1,
        name: "67-3",
        scope: :shared,
        trigger: {0, 0}
      },
      %{
        map: "job_hunte",
        x: 113,
        y: 91,
        dir: 0,
        sprite: -1,
        name: "67-4",
        scope: :shared,
        trigger: {0, 0}
      },
      %{
        map: "job_hunte",
        x: 125,
        y: 97,
        dir: 0,
        sprite: -1,
        name: "68-1",
        scope: :shared,
        trigger: {1, 0}
      },
      %{
        map: "job_hunte",
        x: 125,
        y: 96,
        dir: 0,
        sprite: -1,
        name: "68-2",
        scope: :shared,
        trigger: {1, 0}
      },
      %{
        map: "job_hunte",
        x: 127,
        y: 96,
        dir: 0,
        sprite: -1,
        name: "68-3",
        scope: :shared,
        trigger: {0, 0}
      },
      %{
        map: "job_hunte",
        x: 127,
        y: 97,
        dir: 0,
        sprite: -1,
        name: "68-4",
        scope: :shared,
        trigger: {0, 0}
      },
      %{
        map: "job_hunte",
        x: 52,
        y: 86,
        dir: 0,
        sprite: -1,
        name: "69-1",
        scope: :shared,
        trigger: {0, 0}
      },
      %{
        map: "job_hunte",
        x: 52,
        y: 87,
        dir: 0,
        sprite: -1,
        name: "69-2",
        scope: :shared,
        trigger: {0, 0}
      },
      %{
        map: "job_hunte",
        x: 53,
        y: 86,
        dir: 0,
        sprite: -1,
        name: "69-3",
        scope: :shared,
        trigger: {0, 0}
      },
      %{
        map: "job_hunte",
        x: 53,
        y: 87,
        dir: 0,
        sprite: -1,
        name: "69-4",
        scope: :shared,
        trigger: {0, 0}
      },
      %{
        map: "job_hunte",
        x: 66,
        y: 88,
        dir: 0,
        sprite: -1,
        name: "70-1",
        scope: :shared,
        trigger: {0, 0}
      },
      %{
        map: "job_hunte",
        x: 66,
        y: 89,
        dir: 0,
        sprite: -1,
        name: "70-2",
        scope: :shared,
        trigger: {0, 0}
      },
      %{
        map: "job_hunte",
        x: 67,
        y: 88,
        dir: 0,
        sprite: -1,
        name: "70-3",
        scope: :shared,
        trigger: {0, 0}
      },
      %{
        map: "job_hunte",
        x: 67,
        y: 89,
        dir: 0,
        sprite: -1,
        name: "70-4",
        scope: :shared,
        trigger: {0, 0}
      },
      %{
        map: "job_hunte",
        x: 114,
        y: 84,
        dir: 0,
        sprite: -1,
        name: "71-1",
        scope: :shared,
        trigger: {0, 0}
      },
      %{
        map: "job_hunte",
        x: 114,
        y: 85,
        dir: 0,
        sprite: -1,
        name: "71-2",
        scope: :shared,
        trigger: {0, 0}
      },
      %{
        map: "job_hunte",
        x: 115,
        y: 84,
        dir: 0,
        sprite: -1,
        name: "71-3",
        scope: :shared,
        trigger: {0, 0}
      },
      %{
        map: "job_hunte",
        x: 115,
        y: 85,
        dir: 0,
        sprite: -1,
        name: "71-4",
        scope: :shared,
        trigger: {0, 0}
      },
      %{
        map: "job_hunte",
        x: 126,
        y: 86,
        dir: 0,
        sprite: -1,
        name: "72-1",
        scope: :shared,
        trigger: {0, 0}
      },
      %{
        map: "job_hunte",
        x: 126,
        y: 87,
        dir: 0,
        sprite: -1,
        name: "72-2",
        scope: :shared,
        trigger: {0, 0}
      },
      %{
        map: "job_hunte",
        x: 127,
        y: 86,
        dir: 0,
        sprite: -1,
        name: "72-3",
        scope: :shared,
        trigger: {0, 0}
      },
      %{
        map: "job_hunte",
        x: 127,
        y: 87,
        dir: 0,
        sprite: -1,
        name: "72-4",
        scope: :shared,
        trigger: {0, 0}
      },
      %{
        map: "job_hunte",
        x: 54,
        y: 80,
        dir: 0,
        sprite: -1,
        name: "73-1",
        scope: :shared,
        trigger: {0, 1}
      },
      %{
        map: "job_hunte",
        x: 55,
        y: 80,
        dir: 0,
        sprite: -1,
        name: "73-2",
        scope: :shared,
        trigger: {0, 1}
      },
      %{
        map: "job_hunte",
        x: 55,
        y: 80,
        dir: 0,
        sprite: -1,
        name: "73-3",
        scope: :shared,
        trigger: {0, 0}
      },
      %{
        map: "job_hunte",
        x: 55,
        y: 78,
        dir: 0,
        sprite: -1,
        name: "73-4",
        scope: :shared,
        trigger: {0, 0}
      },
      %{
        map: "job_hunte",
        x: 64,
        y: 82,
        dir: 0,
        sprite: -1,
        name: "74-1",
        scope: :shared,
        trigger: {0, 1}
      },
      %{
        map: "job_hunte",
        x: 65,
        y: 82,
        dir: 0,
        sprite: -1,
        name: "74-2",
        scope: :shared,
        trigger: {0, 1}
      },
      %{
        map: "job_hunte",
        x: 64,
        y: 80,
        dir: 0,
        sprite: -1,
        name: "74-3",
        scope: :shared,
        trigger: {0, 0}
      },
      %{
        map: "job_hunte",
        x: 65,
        y: 80,
        dir: 0,
        sprite: -1,
        name: "74-4",
        scope: :shared,
        trigger: {0, 0}
      },
      %{
        map: "job_hunte",
        x: 66,
        y: 78,
        dir: 0,
        sprite: -1,
        name: "75-1",
        scope: :shared,
        trigger: {0, 0}
      },
      %{
        map: "job_hunte",
        x: 66,
        y: 79,
        dir: 0,
        sprite: -1,
        name: "75-2",
        scope: :shared,
        trigger: {0, 0}
      },
      %{
        map: "job_hunte",
        x: 67,
        y: 78,
        dir: 0,
        sprite: -1,
        name: "75-3",
        scope: :shared,
        trigger: {0, 0}
      },
      %{
        map: "job_hunte",
        x: 67,
        y: 79,
        dir: 0,
        sprite: -1,
        name: "75-4",
        scope: :shared,
        trigger: {0, 0}
      },
      %{
        map: "job_hunte",
        x: 74,
        y: 78,
        dir: 0,
        sprite: -1,
        name: "76-1",
        scope: :shared,
        trigger: {0, 0}
      },
      %{
        map: "job_hunte",
        x: 74,
        y: 79,
        dir: 0,
        sprite: -1,
        name: "76-2",
        scope: :shared,
        trigger: {0, 0}
      },
      %{
        map: "job_hunte",
        x: 75,
        y: 78,
        dir: 0,
        sprite: -1,
        name: "76-3",
        scope: :shared,
        trigger: {0, 0}
      },
      %{
        map: "job_hunte",
        x: 75,
        y: 79,
        dir: 0,
        sprite: -1,
        name: "76-4",
        scope: :shared,
        trigger: {0, 0}
      },
      %{
        map: "job_hunte",
        x: 78,
        y: 80,
        dir: 0,
        sprite: -1,
        name: "77-1",
        scope: :shared,
        trigger: {0, 0}
      },
      %{
        map: "job_hunte",
        x: 78,
        y: 81,
        dir: 0,
        sprite: -1,
        name: "77-2",
        scope: :shared,
        trigger: {0, 0}
      },
      %{
        map: "job_hunte",
        x: 79,
        y: 80,
        dir: 0,
        sprite: -1,
        name: "77-3",
        scope: :shared,
        trigger: {0, 0}
      },
      %{
        map: "job_hunte",
        x: 79,
        y: 81,
        dir: 0,
        sprite: -1,
        name: "77-4",
        scope: :shared,
        trigger: {0, 0}
      },
      %{
        map: "job_hunte",
        x: 82,
        y: 78,
        dir: 0,
        sprite: -1,
        name: "78-1",
        scope: :shared,
        trigger: {0, 0}
      },
      %{
        map: "job_hunte",
        x: 82,
        y: 79,
        dir: 0,
        sprite: -1,
        name: "78-2",
        scope: :shared,
        trigger: {0, 0}
      },
      %{
        map: "job_hunte",
        x: 83,
        y: 78,
        dir: 0,
        sprite: -1,
        name: "78-3",
        scope: :shared,
        trigger: {0, 0}
      },
      %{
        map: "job_hunte",
        x: 83,
        y: 79,
        dir: 0,
        sprite: -1,
        name: "78-4",
        scope: :shared,
        trigger: {0, 0}
      },
      %{
        map: "job_hunte",
        x: 94,
        y: 78,
        dir: 0,
        sprite: -1,
        name: "79-1",
        scope: :shared,
        trigger: {0, 0}
      },
      %{
        map: "job_hunte",
        x: 94,
        y: 79,
        dir: 0,
        sprite: -1,
        name: "79-2",
        scope: :shared,
        trigger: {0, 0}
      },
      %{
        map: "job_hunte",
        x: 95,
        y: 78,
        dir: 0,
        sprite: -1,
        name: "79-3",
        scope: :shared,
        trigger: {0, 0}
      },
      %{
        map: "job_hunte",
        x: 95,
        y: 79,
        dir: 0,
        sprite: -1,
        name: "79-4",
        scope: :shared,
        trigger: {0, 0}
      },
      %{
        map: "job_hunte",
        x: 101,
        y: 80,
        dir: 0,
        sprite: -1,
        name: "80-1",
        scope: :shared,
        trigger: {1, 0}
      },
      %{
        map: "job_hunte",
        x: 101,
        y: 81,
        dir: 0,
        sprite: -1,
        name: "80-2",
        scope: :shared,
        trigger: {1, 0}
      },
      %{
        map: "job_hunte",
        x: 103,
        y: 81,
        dir: 0,
        sprite: -1,
        name: "80-3",
        scope: :shared,
        trigger: {0, 0}
      },
      %{
        map: "job_hunte",
        x: 103,
        y: 80,
        dir: 0,
        sprite: -1,
        name: "80-4",
        scope: :shared,
        trigger: {0, 0}
      },
      %{
        map: "job_hunte",
        x: 104,
        y: 78,
        dir: 0,
        sprite: -1,
        name: "81-1",
        scope: :shared,
        trigger: {0, 0}
      },
      %{
        map: "job_hunte",
        x: 104,
        y: 79,
        dir: 0,
        sprite: -1,
        name: "81-2",
        scope: :shared,
        trigger: {0, 0}
      },
      %{
        map: "job_hunte",
        x: 105,
        y: 78,
        dir: 0,
        sprite: -1,
        name: "81-3",
        scope: :shared,
        trigger: {0, 0}
      },
      %{
        map: "job_hunte",
        x: 105,
        y: 79,
        dir: 0,
        sprite: -1,
        name: "81-4",
        scope: :shared,
        trigger: {0, 0}
      },
      %{
        map: "job_hunte",
        x: 110,
        y: 78,
        dir: 0,
        sprite: -1,
        name: "82-1",
        scope: :shared,
        trigger: {0, 0}
      },
      %{
        map: "job_hunte",
        x: 110,
        y: 79,
        dir: 0,
        sprite: -1,
        name: "82-2",
        scope: :shared,
        trigger: {0, 0}
      },
      %{
        map: "job_hunte",
        x: 111,
        y: 78,
        dir: 0,
        sprite: -1,
        name: "82-3",
        scope: :shared,
        trigger: {0, 0}
      },
      %{
        map: "job_hunte",
        x: 111,
        y: 79,
        dir: 0,
        sprite: -1,
        name: "82-4",
        scope: :shared,
        trigger: {0, 0}
      },
      %{
        map: "job_hunte",
        x: 114,
        y: 80,
        dir: 0,
        sprite: -1,
        name: "83-1",
        scope: :shared,
        trigger: {0, 0}
      },
      %{
        map: "job_hunte",
        x: 114,
        y: 81,
        dir: 0,
        sprite: -1,
        name: "83-2",
        scope: :shared,
        trigger: {0, 0}
      },
      %{
        map: "job_hunte",
        x: 115,
        y: 80,
        dir: 0,
        sprite: -1,
        name: "83-3",
        scope: :shared,
        trigger: {0, 0}
      },
      %{
        map: "job_hunte",
        x: 115,
        y: 81,
        dir: 0,
        sprite: -1,
        name: "83-4",
        scope: :shared,
        trigger: {0, 0}
      },
      %{
        map: "job_hunte",
        x: 124,
        y: 78,
        dir: 0,
        sprite: -1,
        name: "84-1",
        scope: :shared,
        trigger: {0, 0}
      },
      %{
        map: "job_hunte",
        x: 124,
        y: 79,
        dir: 0,
        sprite: -1,
        name: "84-2",
        scope: :shared,
        trigger: {0, 0}
      },
      %{
        map: "job_hunte",
        x: 125,
        y: 78,
        dir: 0,
        sprite: -1,
        name: "84-3",
        scope: :shared,
        trigger: {0, 0}
      },
      %{
        map: "job_hunte",
        x: 125,
        y: 79,
        dir: 0,
        sprite: -1,
        name: "84-4",
        scope: :shared,
        trigger: {0, 0}
      },
      %{
        map: "job_hunte",
        x: 126,
        y: 82,
        dir: 0,
        sprite: -1,
        name: "85-1",
        scope: :shared,
        trigger: {0, 0}
      },
      %{
        map: "job_hunte",
        x: 126,
        y: 83,
        dir: 0,
        sprite: -1,
        name: "85-2",
        scope: :shared,
        trigger: {0, 0}
      },
      %{
        map: "job_hunte",
        x: 127,
        y: 82,
        dir: 0,
        sprite: -1,
        name: "85-3",
        scope: :shared,
        trigger: {0, 0}
      },
      %{
        map: "job_hunte",
        x: 127,
        y: 83,
        dir: 0,
        sprite: -1,
        name: "85-4",
        scope: :shared,
        trigger: {0, 0}
      },
      %{
        map: "job_hunte",
        x: 52,
        y: 68,
        dir: 0,
        sprite: -1,
        name: "86-1",
        scope: :shared,
        trigger: {0, 1}
      },
      %{
        map: "job_hunte",
        x: 53,
        y: 68,
        dir: 0,
        sprite: -1,
        name: "86-2",
        scope: :shared,
        trigger: {0, 1}
      },
      %{
        map: "job_hunte",
        x: 52,
        y: 66,
        dir: 0,
        sprite: -1,
        name: "86-3",
        scope: :shared,
        trigger: {0, 0}
      },
      %{
        map: "job_hunte",
        x: 53,
        y: 66,
        dir: 0,
        sprite: -1,
        name: "86-4",
        scope: :shared,
        trigger: {0, 0}
      },
      %{
        map: "job_hunte",
        x: 54,
        y: 70,
        dir: 0,
        sprite: -1,
        name: "87-1",
        scope: :shared,
        trigger: {0, 1}
      },
      %{
        map: "job_hunte",
        x: 55,
        y: 70,
        dir: 0,
        sprite: -1,
        name: "87-2",
        scope: :shared,
        trigger: {0, 1}
      },
      %{
        map: "job_hunte",
        x: 54,
        y: 68,
        dir: 0,
        sprite: -1,
        name: "87-3",
        scope: :shared,
        trigger: {0, 0}
      },
      %{
        map: "job_hunte",
        x: 55,
        y: 68,
        dir: 0,
        sprite: -1,
        name: "87-4",
        scope: :shared,
        trigger: {0, 0}
      },
      %{
        map: "job_hunte",
        x: 59,
        y: 66,
        dir: 0,
        sprite: -1,
        name: "88-1",
        scope: :shared,
        trigger: {1, 0}
      },
      %{
        map: "job_hunte",
        x: 59,
        y: 67,
        dir: 0,
        sprite: -1,
        name: "88-2",
        scope: :shared,
        trigger: {1, 0}
      },
      %{
        map: "job_hunte",
        x: 61,
        y: 67,
        dir: 0,
        sprite: -1,
        name: "88-3",
        scope: :shared,
        trigger: {0, 0}
      },
      %{
        map: "job_hunte",
        x: 61,
        y: 66,
        dir: 0,
        sprite: -1,
        name: "88-4",
        scope: :shared,
        trigger: {0, 0}
      },
      %{
        map: "job_hunte",
        x: 68,
        y: 68,
        dir: 0,
        sprite: -1,
        name: "89-1",
        scope: :shared,
        trigger: {0, 1}
      },
      %{
        map: "job_hunte",
        x: 69,
        y: 68,
        dir: 0,
        sprite: -1,
        name: "89-2",
        scope: :shared,
        trigger: {0, 1}
      },
      %{
        map: "job_hunte",
        x: 68,
        y: 66,
        dir: 0,
        sprite: -1,
        name: "89-3",
        scope: :shared,
        trigger: {0, 0}
      },
      %{
        map: "job_hunte",
        x: 69,
        y: 66,
        dir: 0,
        sprite: -1,
        name: "89-4",
        scope: :shared,
        trigger: {0, 0}
      },
      %{
        map: "job_hunte",
        x: 76,
        y: 66,
        dir: 0,
        sprite: -1,
        name: "90-1",
        scope: :shared,
        trigger: {0, 0}
      },
      %{
        map: "job_hunte",
        x: 76,
        y: 67,
        dir: 0,
        sprite: -1,
        name: "90-2",
        scope: :shared,
        trigger: {0, 0}
      },
      %{
        map: "job_hunte",
        x: 77,
        y: 66,
        dir: 0,
        sprite: -1,
        name: "90-3",
        scope: :shared,
        trigger: {0, 0}
      },
      %{
        map: "job_hunte",
        x: 77,
        y: 67,
        dir: 0,
        sprite: -1,
        name: "90-4",
        scope: :shared,
        trigger: {0, 0}
      },
      %{
        map: "job_hunte",
        x: 82,
        y: 68,
        dir: 0,
        sprite: -1,
        name: "91-1",
        scope: :shared,
        trigger: {0, 0}
      },
      %{
        map: "job_hunte",
        x: 82,
        y: 69,
        dir: 0,
        sprite: -1,
        name: "91-2",
        scope: :shared,
        trigger: {0, 0}
      },
      %{
        map: "job_hunte",
        x: 83,
        y: 68,
        dir: 0,
        sprite: -1,
        name: "91-3",
        scope: :shared,
        trigger: {0, 0}
      },
      %{
        map: "job_hunte",
        x: 83,
        y: 69,
        dir: 0,
        sprite: -1,
        name: "91-4",
        scope: :shared,
        trigger: {0, 0}
      },
      %{
        map: "job_hunte",
        x: 96,
        y: 66,
        dir: 0,
        sprite: -1,
        name: "92-1",
        scope: :shared,
        trigger: {0, 0}
      },
      %{
        map: "job_hunte",
        x: 96,
        y: 67,
        dir: 0,
        sprite: -1,
        name: "92-2",
        scope: :shared,
        trigger: {0, 0}
      },
      %{
        map: "job_hunte",
        x: 97,
        y: 66,
        dir: 0,
        sprite: -1,
        name: "92-3",
        scope: :shared,
        trigger: {0, 0}
      },
      %{
        map: "job_hunte",
        x: 97,
        y: 67,
        dir: 0,
        sprite: -1,
        name: "92-4",
        scope: :shared,
        trigger: {0, 0}
      },
      %{
        map: "job_hunte",
        x: 100,
        y: 68,
        dir: 0,
        sprite: -1,
        name: "93-1",
        scope: :shared,
        trigger: {0, 0}
      },
      %{
        map: "job_hunte",
        x: 100,
        y: 69,
        dir: 0,
        sprite: -1,
        name: "93-2",
        scope: :shared,
        trigger: {0, 0}
      },
      %{
        map: "job_hunte",
        x: 101,
        y: 68,
        dir: 0,
        sprite: -1,
        name: "93-3",
        scope: :shared,
        trigger: {0, 0}
      },
      %{
        map: "job_hunte",
        x: 101,
        y: 69,
        dir: 0,
        sprite: -1,
        name: "93-4",
        scope: :shared,
        trigger: {0, 0}
      },
      %{
        map: "job_hunte",
        x: 107,
        y: 66,
        dir: 0,
        sprite: -1,
        name: "94-1",
        scope: :shared,
        trigger: {1, 0}
      },
      %{
        map: "job_hunte",
        x: 107,
        y: 67,
        dir: 0,
        sprite: -1,
        name: "94-2",
        scope: :shared,
        trigger: {1, 0}
      },
      %{
        map: "job_hunte",
        x: 109,
        y: 67,
        dir: 0,
        sprite: -1,
        name: "94-3",
        scope: :shared,
        trigger: {0, 0}
      },
      %{
        map: "job_hunte",
        x: 109,
        y: 66,
        dir: 0,
        sprite: -1,
        name: "94-4",
        scope: :shared,
        trigger: {0, 0}
      },
      %{
        map: "job_hunte",
        x: 117,
        y: 69,
        dir: 0,
        sprite: -1,
        name: "95-1",
        scope: :shared,
        trigger: {1, 0}
      },
      %{
        map: "job_hunte",
        x: 117,
        y: 68,
        dir: 0,
        sprite: -1,
        name: "95-2",
        scope: :shared,
        trigger: {1, 0}
      },
      %{
        map: "job_hunte",
        x: 119,
        y: 69,
        dir: 0,
        sprite: -1,
        name: "95-3",
        scope: :shared,
        trigger: {0, 0}
      },
      %{
        map: "job_hunte",
        x: 119,
        y: 68,
        dir: 0,
        sprite: -1,
        name: "95-4",
        scope: :shared,
        trigger: {0, 0}
      },
      %{
        map: "job_hunte",
        x: 124,
        y: 66,
        dir: 0,
        sprite: -1,
        name: "96-1",
        scope: :shared,
        trigger: {0, 0}
      },
      %{
        map: "job_hunte",
        x: 124,
        y: 67,
        dir: 0,
        sprite: -1,
        name: "96-2",
        scope: :shared,
        trigger: {0, 0}
      },
      %{
        map: "job_hunte",
        x: 125,
        y: 66,
        dir: 0,
        sprite: -1,
        name: "96-3",
        scope: :shared,
        trigger: {0, 0}
      },
      %{
        map: "job_hunte",
        x: 125,
        y: 67,
        dir: 0,
        sprite: -1,
        name: "96-4",
        scope: :shared,
        trigger: {0, 0}
      },
      %{
        map: "job_hunte",
        x: 126,
        y: 70,
        dir: 0,
        sprite: -1,
        name: "97-1",
        scope: :shared,
        trigger: {0, 0}
      },
      %{
        map: "job_hunte",
        x: 126,
        y: 71,
        dir: 0,
        sprite: -1,
        name: "97-2",
        scope: :shared,
        trigger: {0, 0}
      },
      %{
        map: "job_hunte",
        x: 127,
        y: 70,
        dir: 0,
        sprite: -1,
        name: "97-3",
        scope: :shared,
        trigger: {0, 0}
      },
      %{
        map: "job_hunte",
        x: 127,
        y: 71,
        dir: 0,
        sprite: -1,
        name: "97-4",
        scope: :shared,
        trigger: {0, 0}
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_event(String.t(), Ctx.t()) :: Ctx.t()
  def on_event("OnTouch_", ctx) do
    ctx
    |> mapannounce(
      "job_hunte",
      "#{char_name(ctx, 0)}, has failed me! Go back to where you started!",
      1
    )
    |> set_char_var(:HNTR_Q, 13)
    |> warp("job_hunte", 176, 22)
    |> donpcevent("Manager#hnt::OnReset")
    |> donpcevent("Waiting Room#hnt::OnStart")
  end

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  # rAthena starts a click at the first label, so it runs this body too.
  def on_talk(ctx), do: on_event("OnTouch_", ctx)
end
