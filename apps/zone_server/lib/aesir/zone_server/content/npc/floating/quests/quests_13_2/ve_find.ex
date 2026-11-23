defmodule Aesir.ZoneServer.Content.Npc.Floating.Quests.Quests132.VeFind do
  @moduledoc """
  Offers mineral mining during the Thor Volcano quest.

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
      %{
        map: "ve_fild03",
        x: 152,
        y: 134,
        dir: 3,
        sprite: 111,
        name: "",
        scope: :shared,
        unique_name: "#ve_01",
        trigger: {10, 10}
      },
      %{
        map: "ve_fild03",
        x: 256,
        y: 228,
        dir: 3,
        sprite: 111,
        name: "",
        scope: :shared,
        unique_name: "#ve_02",
        trigger: {10, 10}
      },
      %{
        map: "ve_fild03",
        x: 85,
        y: 189,
        dir: 3,
        sprite: 111,
        name: "",
        scope: :shared,
        unique_name: "#ve_03",
        trigger: {10, 10}
      },
      %{
        map: "ve_fild03",
        x: 282,
        y: 268,
        dir: 3,
        sprite: 111,
        name: "",
        scope: :shared,
        unique_name: "#ve_04",
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
      get_char_var(ctx, :ep13_2_tre, 0) != 4 or count_item(ctx, 6076) != 1 ->
        ctx

      count_item(ctx, 6077) >= 5 ->
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
          1 -> 2
          _ -> 1
        end

      ctx = give_item(ctx, 6077, amount)

      ctx
      |> donpcevent(Rathena.concat(strnpcinfo(ctx, 0), "_t::OnEnable"))
      |> disablenpc()
      |> close()
    end
  end

  def ev_oninit(ctx), do: enablenpc(ctx)

  def ev_ontouch(ctx) do
    if get_char_var(ctx, :ep13_2_tre, 0) == 4 and count_item(ctx, 6076) == 1 and
         count_item(ctx, 6077) < 5 do
      specialeffect(ctx, :couplecasting)
    else
      ctx
    end
  end
end
