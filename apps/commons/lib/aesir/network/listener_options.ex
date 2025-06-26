defmodule Aesir.Network.ListenerOptions do
  @schema NimbleOptions.new!(
            ref: [
              type: :reference,
              required: true,
              doc: "Unique reference for the listener"
            ],
            connection_module: [
              type: :atom,
              required: true,
              doc: "Module to handle connections"
            ],
            packet_registry: [
              type: :atom,
              required: true,
              doc: "Module for packet registration"
            ],
            transport_opts: [
              type: :map,
              default: %{
                num_acceptors: 10,
                max_connections: 5000,
                socket_opts: [
                  port: 6900,
                  ip: {0, 0, 0, 0},
                  nodelay: true,
                  keepalive: true
                ]
              },
              doc: "Transport options for the listener",
              keys: [
                num_acceptors: [
                  type: :pos_integer,
                  default: 10,
                  doc: "Number of acceptor processes"
                ],
                max_connections: [
                  type: :pos_integer,
                  default: 5000,
                  doc: "Maximum number of concurrent connections"
                ],
                socket_opts: [
                  type: :keyword_list,
                  default: [
                    port: 6900,
                    ip: {127, 0, 0, 1},
                    nodelay: true,
                    keepalive: true
                  ],
                  keys: [
                    port: [
                      type: :pos_integer,
                      required: true,
                      default: 6900,
                      doc: "Port to listen on"
                    ],
                    ip: [
                      type:
                        {:tuple,
                         [:non_neg_integer, :non_neg_integer, :non_neg_integer, :non_neg_integer]},
                      default: {127, 0, 0, 1},
                      doc: "IP address to bind to"
                    ],
                    nodelay: [
                      type: :boolean,
                      default: true,
                      doc: "Enable TCP no delay"
                    ],
                    keepalive: [
                      type: :boolean,
                      default: true,
                      doc: "Enable TCP keepalive"
                    ]
                  ]
                ]
              ]
            ]
          )

  def validate!(config) do
    config = NimbleOptions.validate!(config, @schema)

    {ref, config} = Keyword.pop(config, :ref)
    {connection_mod, config} = Keyword.pop(config, :connection_module)
    {registry, config} = Keyword.pop(config, :packet_registry)

    {ref, registry, connection_mod, config[:transport_opts]}
  end
end
