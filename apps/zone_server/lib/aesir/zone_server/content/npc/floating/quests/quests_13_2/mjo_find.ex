defmodule Aesir.ZoneServer.Content.Npc.Floating.Quests.Quests132.MjoFind do
  @moduledoc """
  Offers mineral mining during the Mt. Mjolnir quest.

  ## Behavior

  - Shows an effect to eligible players and offers a mining attempt.
  - Awards minerals or fragments and temporarily disables successful deposits.

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
      %{name: "mjo_find"},
      %{
        map: "mjolnir_01",
        x: 32,
        y: 309,
        dir: 3,
        sprite: 111,
        name: "",
        scope: :shared,
        unique_name: "#mj01_01",
        trigger: {7, 7}
      },
      %{
        map: "mjolnir_01",
        x: 217,
        y: 34,
        dir: 3,
        sprite: 111,
        name: "",
        scope: :shared,
        unique_name: "#mj01_02",
        trigger: {7, 7}
      },
      %{
        map: "mjolnir_02",
        x: 90,
        y: 195,
        dir: 3,
        sprite: 111,
        name: "",
        scope: :shared,
        unique_name: "#mj02_01",
        trigger: {5, 10}
      },
      %{
        map: "mjolnir_02",
        x: 206,
        y: 187,
        dir: 3,
        sprite: 111,
        name: "",
        scope: :shared,
        unique_name: "#mj02_02",
        trigger: {7, 7}
      },
      %{
        map: "mjolnir_04",
        x: 125,
        y: 380,
        dir: 3,
        sprite: 111,
        name: "",
        scope: :shared,
        unique_name: "#mj04_01",
        trigger: {7, 7}
      },
      %{
        map: "mjolnir_04",
        x: 220,
        y: 130,
        dir: 3,
        sprite: 111,
        name: "",
        scope: :shared,
        unique_name: "#mj04_02",
        trigger: {7, 7}
      },
      %{
        map: "mjolnir_09",
        x: 229,
        y: 214,
        dir: 3,
        sprite: 111,
        name: "",
        scope: :shared,
        unique_name: "#mj09_01",
        trigger: {10, 10}
      },
      %{
        map: "mjolnir_10",
        x: 188,
        y: 260,
        dir: 3,
        sprite: 111,
        name: "",
        scope: :shared,
        unique_name: "#mj10_01",
        trigger: {10, 10}
      }
    ]

  alias Aesir.ZoneServer.Script.Rathena
  @impl true
  def on_event("OnInit", ctx) do
    ev_oninit(ctx)
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  def on_event("OnTouch_", ctx) do
    ev_ontouch(ctx)
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  @impl true
  def on_talk(ctx) do
    cond do
      get_char_var(ctx, :ep13_2_tre, 0) != 2 or count_item(ctx, 6076) != 1 ->
        ctx

      count_item(ctx, 6077) >= 10 ->
        ctx |> mes("- I think I have enough minerals. -") |> close()

      true ->
        offer_mining(ctx)
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  defp offer_mining(ctx) do
    {ctx, choice} =
      ctx
      |> mes(
        "- I can see some different colored minerals where the detector pointed to. This must be the mineral that Mr. Lifeguard told me about. -"
      )
      |> next()
      |> select(["Mine minerals.", "Do nothing."])

    case choice do
      1 -> mine(ctx)
      2 -> ctx |> mes("- You decide to do nothing. -") |> close()
      _ -> ctx
    end
  end

  defp mine(ctx) do
    ctx = ctx |> mes("Clang! Clang! Clang! Clang!") |> close() |> progressbar("ffff00", 4)

    if Enum.random(1..6) < 4 do
      ctx |> mes("- You failed to mine minerals. -") |> give_item(6078, 1) |> close()
    else
      ctx = mes(ctx, "- You succeeded to mine minerals. -")
      ctx = ctx |> emotion(:aha, playerattached(ctx)) |> set_local(:stst, Enum.random(1..5))

      amount =
        case get_local(ctx, :stst, 0) do
          5 -> 5
          1 -> 1
          _ -> 2
        end

      ctx = give_item(ctx, 6077, amount)
      ctx = close(ctx)
      ctx |> donpcevent(Rathena.concat(strnpcinfo(ctx, 0), "_t::OnEnable")) |> disablenpc()
    end
  end

  def ev_oninit(ctx), do: enablenpc(ctx)

  def ev_ontouch(ctx) do
    if get_char_var(ctx, :ep13_2_tre, 0) == 2 and count_item(ctx, 6076) == 1 and
         count_item(ctx, 6077) < 10 do
      specialeffect(ctx, :couplecasting)
    else
      ctx
    end
  end
end
