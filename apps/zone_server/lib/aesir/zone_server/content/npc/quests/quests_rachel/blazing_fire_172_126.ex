defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsRachel.BlazingFire172126 do
  @moduledoc """
  A magical flame guarding the ice cave boss.

  ## Behavior

  - Eligible players can extinguish it with snow powder or an ice scale.
  - Extinguishing all four flames starts the boss encounter.

  ## Credits

  - Original from rAthena, authors and Contributors
    - L0ne_W0lf
    - Euphy

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "ice_dun03",
        x: 172,
        y: 126,
        dir: 0,
        sprite: 802,
        name: "Blazing Fire",
        scope: :shared,
        unique_name: "Blazing Fire#ice2"
      }
    ]

  @impl true
  def on_talk(ctx) do
    ctx =
      ctx
      |> mes("^3355FFThe flames in this fire")
      |> mes("barrier crackle with magic")
      |> mes("power. There's no way that")
      |> mes("you can put this fire out")
      |> mes("with conventional means.^000000")

    ctx =
      if get_char_var(ctx, :ice_necklace_q, 0) > 4 and
           get_server_temp_var(ctx, "ktullanux_summon", 0) < 4 do
        cond do
          count_item(ctx, 7574) > 0 -> extinguish_with_powder(ctx)
          count_item(ctx, 7562) > 0 -> extinguish_with_scale(ctx)
          true -> ctx
        end
      else
        ctx
      end

    close(ctx)
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  defp extinguish_with_powder(ctx) do
    {ctx, _} = ctx |> next() |> select(["Use Freezing Snow Powder."])

    ctx
    |> mes("^3355FFYou sprinkle the Freezing Snow")
    |> mes("Powder onto the flame. It")
    |> mes("flickers before extinguising.^000000")
    |> extinguish(7574)
  end

  defp extinguish_with_scale(ctx) do
    {ctx, _} = ctx |> next() |> select(["Use Ice Scale."])

    ctx
    |> mes("^3355FFYou throw the Ice Scale into")
    |> mes("the flame, it crackles before")
    |> mes("extinguising.^000000")
    |> extinguish(7562)
  end

  defp extinguish(ctx, item) do
    ctx =
      ctx
      |> delitem(item, 1)
      |> hideonnpc("Blazing Fire#ice2")

    ctx =
      set_server_temp_var(
        ctx,
        "ktullanux_summon",
        get_server_temp_var(ctx, "ktullanux_summon", 0) + 1
      )

    if get_server_temp_var(ctx, "ktullanux_summon", 0) == 4 do
      donpcevent(ctx, "ice_boss#broad::OnStart")
    else
      ctx
    end
  end
end
