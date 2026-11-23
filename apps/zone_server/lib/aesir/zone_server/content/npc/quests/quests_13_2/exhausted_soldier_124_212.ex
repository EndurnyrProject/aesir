defmodule Aesir.ZoneServer.Content.Npc.Quests.Quests132.ExhaustedSoldier124212 do
  @moduledoc """
  Lets an exhausted soldier receive Alfheim perfume.

  ## Behavior

  - Requires language access and the active perfume quest to offer perfume use.
  - Consumes perfume and temporarily disables the soldier when used.

  ## Credits

  - Original from rAthena, authors and contributors:
    - L0ne_W0lf
    - Gepard
    - Masao
    - Euphy
    - Joseph
    - Jeybla
    - Mazvi

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "splendide",
        x: 124,
        y: 212,
        dir: 5,
        sprite: 447,
        name: "Exhausted Soldier",
        scope: :shared,
        unique_name: "Exhausted Soldier#6"
      }
    ]

  @impl true
  def on_event("OnInit", ctx) do
    ev_oninit(ctx)
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  @impl true
  def on_talk(ctx) do
    cond do
      is_equipped(ctx, 2782) != 1 or get_char_var(ctx, :ep13_2_rhea, 0) != 100 ->
        ctx |> mes("[Exhausted Soldier]") |> mes("CyaResehr") |> close()

      get_char_var(ctx, :ep13_2_tre1, 0) != 5 ->
        ctx |> mes("[Exhausted Soldier]") |> mes("Huu...") |> close()

      count_item(ctx, 6082) > 0 ->
        offer_perfume(ctx)

      true ->
        ctx
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  defp offer_perfume(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Exhausted Soldier]")
      |> mes("Huu...")
      |> next()
      |> select(["Use perfume.", "Don't use perfume."])

    case choice do
      1 ->
        ctx
        |> mes("(Spray-)")
        |> specialeffect(:sanctuary)
        |> next()
        |> mes("[Exhausted Soldier]")
        |> mes("I can feel the scent of Alfheim.")
        |> mes("My hometown Alfheim!")
        |> next()
        |> mes("[Exhausted Soldier]")
        |> mes("Yes, Splendide also a part of Alfheim!")
        |> mes("Go Laphines!")
        |> emotion(:smile)
        |> delitem(6082, 1)
        |> close()
        |> donpcevent("#tukare_6::OnEnable")
        |> disablenpc("Exhausted Soldier#6")

      2 ->
        ctx |> mes("- You decide to do nothing. -") |> close()

      _ ->
        ctx
    end
  end

  def ev_oninit(ctx) do
    enablenpc(ctx, "Exhausted Soldier#6")
  end
end
