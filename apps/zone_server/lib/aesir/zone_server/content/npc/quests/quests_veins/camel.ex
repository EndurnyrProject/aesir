defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsVeins.Camel do
  @moduledoc """
  A camel rejects the appetite stimulant during the camel quest.

  ## Behavior

  - Advances the quest when first offered the stimulant.

  ## Credits

  - Original from rAthena, authors and Contributors
    - L0ne_W0lf
    - Toms
    - Euphy
    - Joseph
    - Everade

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "veins",
        x: 78,
        y: 226,
        dir: 5,
        sprite: 938,
        name: "Camel",
        scope: :shared,
        unique_name: "VeinsCamel",
        hidden_name: "camelcc1"
      },
      %{
        map: "veins",
        x: 72,
        y: 227,
        dir: 3,
        sprite: 938,
        name: "Camel",
        scope: :shared,
        unique_name: "Camel#camelcc3"
      },
      %{
        map: "veins",
        x: 81,
        y: 222,
        dir: 1,
        sprite: 938,
        name: "Camel",
        scope: :shared,
        unique_name: "Camel#camelcc4"
      },
      %{
        map: "veins",
        x: 77,
        y: 219,
        dir: 5,
        sprite: 938,
        name: "Camel",
        scope: :shared,
        unique_name: "Camel#camelcc5"
      },
      %{
        map: "veins",
        x: 73,
        y: 215,
        dir: 8,
        sprite: 938,
        name: "Camel",
        scope: :shared,
        unique_name: "Camel#camelcc6"
      },
      %{
        map: "veins",
        x: 68,
        y: 215,
        dir: 5,
        sprite: 938,
        name: "Camel",
        scope: :shared,
        unique_name: "Camel#camelcc7"
      }
    ]

  @impl true
  def on_talk(ctx) do
    case get_char_var(ctx, :rachel_camel, 0) do
      9 ->
        ctx
        |> mes("^3355FFThe camel sniffed the")
        |> mes("appetite stimulant, but")
        |> mes("brusquely turned its")
        |> mes("nose away from it.^000000")
        |> changequest(3068, 3069)
        |> set_char_var(:rachel_camel, 10)
        |> close()

      10 ->
        ctx
        |> mes("^3355FFThe camel sniffed the")
        |> mes("appetite stimulant, but")
        |> mes("brusquely turned its")
        |> mes("nose away from it.")
        |> mes("This probably isn't the")
        |> mes("camel you're looking for.^000000")
        |> close()

      _ ->
        ctx |> mes("[Camel]") |> mes("*Neigh* ~") |> mes("*Chew Chew*") |> close()
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end
end
