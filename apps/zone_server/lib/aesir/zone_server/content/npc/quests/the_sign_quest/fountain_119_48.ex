defmodule Aesir.ZoneServer.Content.Npc.Quests.TheSignQuest.Fountain11948 do
  @moduledoc """
  Opens the Geffenia portal when shown Lucifer’s Lament.

  ## Behavior

  - Allows a player carrying Lucifer’s Lament to open the portal or ignore its light.

  ## Credits

  - Original from rAthena, authors and Contributors
    - SinSloth
    - MasterOfMuppets
    - Kargha
    - L0ne_W0lf
    - Kazukin
    - Kisuka
    - CalciumKid
    - tr0n
    - Euphy
    - Joseph
    - Capuche

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "geffen",
        x: 119,
        y: 48,
        dir: 0,
        sprite: 111,
        name: "Fountain",
        scope: :shared,
        unique_name: "Fountain#s"
      }
    ]

  alias Aesir.ZoneServer.Content.Npc.Functions.FUpdatesignvars

  @impl true
  def on_talk(ctx) do
    {ctx, _} = FUpdatesignvars.call(ctx, [])

    if count_item(ctx, 7025) > 0 do
      {ctx, choice} =
        ctx
        |> mes("^3355FFAs you approach the fountain,")
        |> mes(
          "a strange light begins to emit from the Lucifer's Lament in your pocket and from something deep within"
        )
        |> mes("the fountain's water.^000000")
        |> specialeffect(:level99)
        |> specialeffect2(:level99)
        |> next()
        |> select(["Throw Lucifer's Lament into the fountain.", "Ignore the light."])

      case choice do
        1 ->
          ctx
          |> mapannounce(
            "geffen",
            "With a flash of light from Geffen Fountain, the door to Geffenia has opened.",
            1,
            "0x9CFF00"
          )
          |> mes("^3355FFOnce the Lucifer's Lament")
          |> mes("splashes into the water, the")
          |> mes("light reveals a peculiar warp")
          |> mes("in front of the fountain...^000000")
          |> specialeffect(:mappillar2)
          |> donpcevent("Geffenia Warp::OnEnable")
          |> close()

        2 ->
          ctx |> mes(".......") |> close()

        _ ->
          ctx
      end
    else
      ctx |> mes("^3355FFThis is the") |> mes("Geffen Fountain.^000000") |> close()
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end
end
