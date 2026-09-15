defmodule Aesir.ZoneServer.Content.Npc.Cities.Louyang.Trainee do
  @moduledoc """
  Voices martial arts trainees' practice cries.

  ## Credits

  - Original from rAthena, authors and Contributors
    - Vidar
    - Mass Zero
    - Dino9021
    - Celest
    - MasterOfMuppets
    - rAthena Dev Team

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "louyang",
        x: 276,
        y: 133,
        dir: 0,
        sprite: 819,
        name: "Trainee",
        scope: :shared,
        unique_name: "LouTrainee"
      },
      %{
        map: "louyang",
        x: 278,
        y: 133,
        dir: 0,
        sprite: 819,
        name: "Trainee",
        scope: :shared,
        unique_name: "Trainee#7lou"
      },
      %{
        map: "louyang",
        x: 278,
        y: 131,
        dir: 0,
        sprite: 819,
        name: "Trainee",
        scope: :shared,
        unique_name: "Trainee#8lou"
      },
      %{
        map: "louyang",
        x: 278,
        y: 129,
        dir: 0,
        sprite: 819,
        name: "Trainee",
        scope: :shared,
        unique_name: "Trainee#9lou"
      },
      %{
        map: "louyang",
        x: 272,
        y: 133,
        dir: 0,
        sprite: 819,
        name: "Trainee",
        scope: :shared,
        unique_name: "Trainee#10lou"
      },
      %{
        map: "louyang",
        x: 272,
        y: 131,
        dir: 0,
        sprite: 819,
        name: "Trainee",
        scope: :shared,
        unique_name: "Trainee#11lou"
      },
      %{
        map: "louyang",
        x: 272,
        y: 129,
        dir: 0,
        sprite: 819,
        name: "Trainee",
        scope: :shared,
        unique_name: "Trainee#12lou"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx |> mes("[Trainee]") |> mes("Yeeeyap~!") |> mes("Taaaaaah~~!!") |> mes("Hooo~.") |> close()
  end
end
