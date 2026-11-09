defmodule Aesir.ZoneServer.Content.Npc.Quests.Quests131.Valdes do
  @moduledoc """
  Valdes, the master of the Morocc job quest's room 1, who turns away every visitor because of
  his headache.

  ## Behavior

  - Assassins get a first, warmer refusal; everyone else a blunt one.
  - Either way the room withdraws every unit of the three request items the player carries and
    closes the dialog.
  - Hides itself on boot and when disabled, and reveals itself when enabled.

  ## Credits

  - Original from rAthena, authors and Contributors
    - L0ne_W0lf
    - Joseph
    - Euphy
    - Capuche

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script quests/quests_13_1.txt
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "que_job01",
        x: 16,
        y: 21,
        dir: 5,
        sprite: 55,
        name: "Valdes",
        scope: :shared,
        unique_name: "Valdes#moc_master_1"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx
  alias Aesir.ZoneServer.Script.Rathena

  @npc "Valdes#moc_master_1"

  # Quest items the room withdraws from every visitor, whatever their class.
  @request_items [6029, 7418, 7416]

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx = mes(ctx, "[Valdes]")

    if Rathena.job_id(base_class(ctx)) == Rathena.job_id(:assassin) do
      assassin_lines(ctx)
    else
      dismissal(ctx)
    end
  end

  @impl true
  @spec on_event(String.t(), Ctx.t()) :: Ctx.t()
  def on_event("OnInit", ctx), do: disablenpc(ctx, @npc)
  def on_event("OnDisable", ctx), do: disablenpc(ctx, @npc)
  def on_event("OnEnable", ctx), do: enablenpc(ctx, @npc)

  defp assassin_lines(ctx) do
    ctx
    |> mes("What is it? I have nothing to ask you to do.")
    |> mes("Could you please leave me alone? I have a bad headache.")
    |> next()
    |> mes("[Valdes]")
    |> mes("I'll ask you for a help some other time.")
    |> mes("You look pretty passionate after all.")
    |> withdraw_requests()
  end

  defp dismissal(ctx) do
    ctx
    |> mes("...Sorry, but could you please leave?")
    |> mes("I'm really stressed out right now.")
    |> mes("If you're here for the request that we made earlier, you can just forget about it.")
    |> withdraw_requests()
  end

  defp withdraw_requests(ctx) do
    ctx
    |> withdraw(@request_items)
    |> close()
  end

  defp withdraw(ctx, []), do: ctx

  defp withdraw(ctx, [item | rest]) do
    held = count_item(ctx, item)
    ctx = if held > 0, do: delitem(ctx, item, held), else: ctx

    withdraw(ctx, rest)
  end
end
