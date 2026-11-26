defmodule Aesir.ZoneServer.Content.Npc.Quests.TheSignQuest.Pleur16183 do
  @moduledoc """
  Pleur talks about the Stone of Sage.

  ## Behavior

  - Her dialogue changes with quest progress; events trigger her expressions.

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
        map: "prt_maze02",
        x: 16,
        y: 183,
        dir: 3,
        sprite: 91,
        name: "Pleur",
        scope: :shared,
        unique_name: "Pleur#sign"
      }
    ]

  alias Aesir.ZoneServer.Content.Npc.Functions.FUpdatesignvars

  @impl true
  def on_event("OnHo", ctx) do
    ev_onho(ctx)
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  def on_event("OnKis2", ctx) do
    ev_onkis2(ctx)
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  def on_event("OnGasp", ctx) do
    ev_ongasp(ctx)
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  def on_event("OnOmg", ctx) do
    ev_onomg(ctx)
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  @impl true
  def on_talk(ctx) do
    {ctx, _} = FUpdatesignvars.call(ctx, [])
    ctx = mes(ctx, "[Pleur]")

    ctx =
      if get_char_var(ctx, :sign_q, 0) < 19 do
        ctx |> mes("La la la~") |> mes("La la la~")
      else
        ctx |> mes("Hmmm...?") |> mes("The Stone of Sage...")
      end

    close(ctx)
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  def ev_onho(ctx) do
    emotion(ctx, :delight)
  end

  def ev_onkis2(ctx) do
    emotion(ctx, :chupchup)
  end

  def ev_ongasp(ctx) do
    emotion(ctx, :surprise)
  end

  def ev_onomg(ctx) do
    emotion(ctx, :huk)
  end
end
